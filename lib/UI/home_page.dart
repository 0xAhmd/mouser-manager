import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/server_manager.dart';
import '../services/network_utils.dart';
import 'server_card.dart';
import 'logs_view.dart';

class HomePage extends HookWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final serverManager = useMemoized(() => ServerManager());
    final networkUtils = useMemoized(() => NetworkUtils());
    
    final isServerRunning = useState(false);
    final serverIp = useState<String>('');
    final serverPort = useState(8080);
    final logs = useState<List<String>>([]);
    final isLoading = useState(false);

    // Initialize
    useEffect(() {
      _initializeApp(serverManager, networkUtils, serverIp, isServerRunning);
      return null;
    }, []);

    // Server logs listener
    useEffect(() {
      final subscription = serverManager.logStream.listen((log) {
        logs.value = [...logs.value, log];
        // Keep only last 100 logs
        if (logs.value.length > 100) {
          logs.value = logs.value.sublist(logs.value.length - 100);
        }
      });
      
      return subscription.cancel;
    }, []);

    // Server status listener
    useEffect(() {
      final subscription = serverManager.statusStream.listen((status) {
        isServerRunning.value = status;
        if (!status) {
          logs.value = [...logs.value, '🔴 Server stopped'];
        }
      });
      
      return subscription.cancel;
    }, []);

    Future<void> startServer() async {
      isLoading.value = true;
      try {
        await serverManager.startServer();
        logs.value = [...logs.value, '🟢 Server starting...'];
      } catch (e) {
        logs.value = [...logs.value, '❌ Failed to start server: $e'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start server: $e')),
        );
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> stopServer() async {
      isLoading.value = true;
      try {
        await serverManager.stopServer();
        logs.value = [...logs.value, '🔴 Server stopping...'];
      } catch (e) {
        logs.value = [...logs.value, '❌ Failed to stop server: $e'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop server: $e')),
        );
      } finally {
        isLoading.value = false;
      }
    }

    final connectionUrl = serverIp.value.isNotEmpty 
        ? 'http://${serverIp.value}:${serverPort.value}'
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.mouse, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Mouser'),
          ],
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),
            
            // Content Row
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column - Server Control & QR
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // Server Status Card
                        ServerCard(
                          isRunning: isServerRunning.value,
                          serverIp: serverIp.value,
                          serverPort: serverPort.value,
                          isLoading: isLoading.value,
                          onStart: startServer,
                          onStop: stopServer,
                        ),
                        const SizedBox(height: 16),
                        
                        // QR Code Card
                        if (connectionUrl.isNotEmpty)
                          _buildQrCard(connectionUrl),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Right Column - Logs
                  Expanded(
                    flex: 1,
                    child: LogsView(logs: logs.value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wireless PC Control Manager',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Control your PC wirelessly from your phone with mouse, keyboard, and file transfer capabilities.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildQrCard(String url) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.qr_code, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Connection QR Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
           
          ],
        ),
      ),
    );
  }

  Future<void> _initializeApp(
    ServerManager serverManager,
    NetworkUtils networkUtils,
    ValueNotifier<String> serverIp,
    ValueNotifier<bool> isServerRunning,
  ) async {
    // Get local IP
    try {
      final ip = await networkUtils.getLocalIpAddress();
      serverIp.value = ip ?? 'localhost';
    } catch (e) {
      serverIp.value = 'localhost';
    }

    // Check if server is already running
    isServerRunning.value = await serverManager.isServerRunning();
  }
}