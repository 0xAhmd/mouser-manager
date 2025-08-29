import 'package:flutter/material.dart';

class LogsView extends StatefulWidget {
  final List<String> logs;

  const LogsView({
    super.key,
    required this.logs,
  });

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void didUpdateWidget(LogsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Auto-scroll to bottom when new logs are added
    if (_autoScroll && widget.logs.length > oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.terminal, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Server Logs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Auto-scroll toggle
                Row(
                  children: [
                    Text(
                      'Auto-scroll',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: _autoScroll,
                      onChanged: (value) {
                        setState(() {
                          _autoScroll = value;
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Clear logs button
                IconButton(
                  icon: Icon(Icons.clear_all, size: 20),
                  onPressed: widget.logs.isEmpty ? null : _clearLogs,
                  tooltip: 'Clear logs',
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Logs container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: widget.logs.isEmpty
                    ? _buildEmptyState()
                    : _buildLogsList(),
              ),
            ),
            
            // Footer
            const SizedBox(height: 8),
            Text(
              '${widget.logs.length} log entries',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No logs yet',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Server logs will appear here',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: widget.logs.length,
      itemBuilder: (context, index) {
        final log = widget.logs[index];
        return _buildLogEntry(log, index);
      },
    );
  }

  Widget _buildLogEntry(String log, int index) {
    // Parse log for styling
    Color? textColor;
    IconData? icon;
    
    if (log.contains('🟢') || log.contains('✅')) {
      textColor = Colors.green[700];
      icon = Icons.check_circle;
    } else if (log.contains('🔴') || log.contains('❌')) {
      textColor = Colors.red[700];
      icon = Icons.error;
    } else if (log.contains('⚠️') || log.contains('warning')) {
      textColor = Colors.orange[700];
      icon = Icons.warning;
    } else if (log.contains('INFO')) {
      textColor = Colors.blue[700];
      icon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: textColor,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              log,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: textColor ?? Colors.grey[800],
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearLogs() {
    // This would need to be handled by the parent widget
    // For now, we'll show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Clear logs functionality needs to be implemented'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}