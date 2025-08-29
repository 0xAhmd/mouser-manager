import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ServerManager {
  Process? _serverProcess;
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  Stream<String> get logStream => _logController.stream;
  Stream<bool> get statusStream => _statusController.stream;

  static const String pythonBackendPath = 'assets/python_backend';
  String? _backendDirectory;

  Future<void> _ensureBackendFiles() async {
    if (_backendDirectory != null) return;

    try {
      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      _backendDirectory = path.join(appDir.path, 'mouser_backend');

      final backendDir = Directory(_backendDirectory!);

      // Check if backend already exists
      if (!await backendDir.exists()) {
        await backendDir.create(recursive: true);

        // Copy Python backend files from assets
        await _copyBackendFiles(backendDir);

        _logController.add('📁 Backend files extracted to: $_backendDirectory');
      } else {
        _logController.add('📁 Using existing backend at: $_backendDirectory');
      }
    } catch (e) {
      _logController.add('❌ Failed to setup backend files: $e');
      throw Exception('Failed to setup backend files: $e');
    }
  }

  Future<void> _copyBackendFiles(Directory targetDir) async {
    // List of backend files to copy
    final files = [
      'main.py',
      'requirements.txt',
      'config/settings.py',
      'controllers/__init__.py',
      'controllers/mouse_controller.py',
      'controllers/keyboard_controller.py',
      'models/__init__.py',
      'models/gesture_state.py',
      'routes/__init__.py',
      'routes/mouse_routes.py',
      'routes/keyboard_routes.py',
      'routes/gesture_routes.py',
      'routes/status_routes.py',
      'routes/file_transfer_routes.py',
      'utils/__init__.py',
      'utils/logger.py',
      'utils/network_utils.py',
      'utils/key_mapper.py',
    ];

    for (final filePath in files) {
      try {
        final assetPath = '$pythonBackendPath/$filePath';
        final content = await rootBundle.loadString(assetPath);

        final targetFile = File(path.join(targetDir.path, filePath));
        await targetFile.create(recursive: true);
        await targetFile.writeAsString(content);
      } catch (e) {
        _logController.add('⚠️ Warning: Could not copy $filePath: $e');
      }
    }
  }

  Future<bool> _checkPythonInstallation() async {
    try {
      // Check if Python 3 is available
      final pythonCommands = ['python3', 'python'];

      for (final cmd in pythonCommands) {
        try {
          final result = await Process.run(cmd, ['--version']);
          if (result.exitCode == 0) {
            final version = result.stdout.toString().trim();
            _logController.add('✅ Found Python: $version');
            return true;
          }
        } catch (e) {
          continue;
        }
      }

      _logController.add('❌ Python not found. Please install Python 3.');
      return false;
    } catch (e) {
      _logController.add('❌ Error checking Python installation: $e');
      return false;
    }
  }

  Future<void> _installDependencies() async {
    if (_backendDirectory == null) return;

    try {
      _logController.add('📦 Installing Python dependencies...');

      final pythonCommands = ['python3', 'python'];
      ProcessResult? result;

      for (final cmd in pythonCommands) {
        try {
          result = await Process.run(cmd, [
            '-m',
            'pip',
            'install',
            '-r',
            'requirements.txt',
          ], workingDirectory: _backendDirectory);

          if (result.exitCode == 0) {
            break;
          }
        } catch (e) {
          continue;
        }
      }

      if (result?.exitCode == 0) {
        _logController.add('✅ Dependencies installed successfully');
      } else {
        _logController.add('⚠️ Failed to install some dependencies');
        _logController.add('Output: ${result?.stdout ?? ""}');
        _logController.add('Error: ${result?.stderr ?? ""}');
      }
    } catch (e) {
      _logController.add('❌ Error installing dependencies: $e');
    }
  }

  Future<void> startServer() async {
    if (_serverProcess != null) {
      _logController.add('⚠️ Server is already running');
      return;
    }

    try {
      // Ensure backend files are ready
      await _ensureBackendFiles();

      // Check Python installation
      if (!await _checkPythonInstallation()) {
        throw Exception('Python 3 is required but not found');
      }

      // Install dependencies
      await _installDependencies();

      _logController.add('🚀 Starting server...');

      // Try different Python commands
      final pythonCommands = ['python3', 'python'];

      for (final cmd in pythonCommands) {
        try {
          _serverProcess = await Process.start(cmd, [
            'main.py',
          ], workingDirectory: _backendDirectory);
          break;
        } catch (e) {
          if (cmd == pythonCommands.last) {
            throw Exception('Could not start Python process: $e');
          }
          continue;
        }
      }

      if (_serverProcess == null) {
        throw Exception('Failed to start server process');
      }

      // Listen to stdout
      _serverProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _logController.add('📝 $line');
          });

      // Listen to stderr
      _serverProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _logController.add('⚠️ $line');
          });

      // Monitor process exit
      _serverProcess!.exitCode.then((exitCode) {
        _logController.add('🔴 Server process exited with code: $exitCode');
        _serverProcess = null;
        _statusController.add(false);
      });

      // Wait a moment to ensure server starts
      await Future.delayed(const Duration(seconds: 2));

      // Check if process is still running
      if (_serverProcess != null) {
        _statusController.add(true);
        _logController.add('✅ Server started successfully');
      } else {
        throw Exception('Server process terminated unexpectedly');
      }
    } catch (e) {
      _logController.add('❌ Failed to start server: $e');
      _serverProcess = null;
      _statusController.add(false);
      rethrow;
    }
  }

  Future<void> stopServer() async {
    if (_serverProcess == null) {
      _logController.add('⚠️ Server is not running');
      return;
    }

    try {
      _logController.add('🛑 Stopping server...');

      // Try graceful shutdown first
      _serverProcess!.kill(ProcessSignal.sigterm);

      // Wait for process to exit
      final exitCode = await _serverProcess!.exitCode.timeout(
        const Duration(seconds: 5),
      );

      _logController.add('✅ Server stopped gracefully (exit code: $exitCode)');
    } catch (e) {
      // Force kill if graceful shutdown fails
      _logController.add('⚠️ Graceful shutdown failed, forcing termination...');
      _serverProcess!.kill(ProcessSignal.sigkill);
      _logController.add('🔴 Server force stopped');
    } finally {
      _serverProcess = null;
      _statusController.add(false);
    }
  }

  Future<bool> isServerRunning() async {
    if (_serverProcess == null) return false;

    try {
      // Try to send a signal to check if process is alive
      final result = _serverProcess!.kill(ProcessSignal.sigusr1);
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkServerHealth() async {
    try {
      // Try to connect to the server health endpoint
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://localhost:8080/ping'),
      );
      request.headers.set('Connection', 'close');

      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      final success = response.statusCode == 200;

      client.close();
      return success;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _serverProcess?.kill();
    _logController.close();
    _statusController.close();
  }
}
