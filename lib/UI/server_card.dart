import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ServerCard extends StatelessWidget {
  final bool isRunning;
  final String serverIp;
  final int serverPort;
  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const ServerCard({
    super.key,
    required this.isRunning,
    required this.serverIp,
    required this.serverPort,
    required this.isLoading,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.router,
                  color: isRunning ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Server Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Status Indicator
            _buildStatusRow(),
            
            const SizedBox(height: 12),
            
            // Server Details
            if (serverIp.isNotEmpty) ...[
              _buildDetailRow('IP Address', serverIp, true),
              const SizedBox(height: 8),
              _buildDetailRow('Port', serverPort.toString(), false),
              const SizedBox(height: 8),
              if (isRunning)
                _buildDetailRow('URL', 'http://$serverIp:$serverPort', true),
            ],
            
            const SizedBox(height: 20),
            
            // Control Buttons
            _buildControlButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLoading
                ? Colors.orange
                : isRunning
                    ? Colors.green
                    : Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isLoading
              ? 'Loading...'
              : isRunning
                  ? 'Running'
                  : 'Stopped',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isLoading
                ? Colors.orange
                : isRunning
                    ? Colors.green
                    : Colors.red,
          ),
        ),
        if (isLoading) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool copyable) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (copyable)
          IconButton(
            icon: Icon(Icons.copy, size: 16, color: Colors.grey[600]),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              // Show feedback (you could add a snackbar here)
            },
            tooltip: 'Copy to clipboard',
          ),
      ],
    );
  }

  Widget _buildControlButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading || isRunning ? null : onStart,
            icon: Icon(Icons.play_arrow),
            label: Text('Start Server'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading || !isRunning ? null : onStop,
            icon: Icon(Icons.stop),
            label: Text('Stop Server'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}