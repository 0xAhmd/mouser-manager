import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ServerManager {
  Process? _serverProcess;
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  Stream<String> get logStream => _logController.stream;
  Stream<bool> get statusStream => _statusController.stream;

  // Use your specific backend path
  static const String backendPath =
      '/home/at4/Documents/flutter-projects/mouser-project/server-side';

  Future<bool> _validateBackendPath() async {
    try {
      final backendDir = Directory(backendPath);
      if (!await backendDir.exists()) {
        _logController.add('❌ Backend directory not found: $backendPath');
        return false;
      }

      // Check if main.py exists
      final mainFile = File('$backendPath/main.py');
      if (!await mainFile.exists()) {
        _logController.add('❌ main.py not found in: $backendPath');
        return false;
      }

      // Check if requirements.txt exists
      final requirementsFile = File('$backendPath/requirements.txt');
      if (!await requirementsFile.exists()) {
        _logController.add('⚠️ requirements.txt not found in: $backendPath');
      }

      _logController.add('✅ Backend found at: $backendPath');
      return true;
    } catch (e) {
      _logController.add('❌ Error validating backend path: $e');
      return false;
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
          ], workingDirectory: backendPath);

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
        if (result?.stdout != null && result!.stdout.toString().isNotEmpty) {
          _logController.add('Output: ${result.stdout}');
        }
        if (result?.stderr != null && result!.stderr.toString().isNotEmpty) {
          _logController.add('Error: ${result.stderr}');
        }
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
      // Validate backend path
      if (!await _validateBackendPath()) {
        throw Exception('Backend validation failed');
      }

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
          ], workingDirectory: backendPath);
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
