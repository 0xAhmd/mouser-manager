import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtils {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Get the local IP address of the device
  Future<String?> getLocalIpAddress() async {
    try {
      // Try using network_info_plus first
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty && wifiIP != '127.0.0.1') {
        return wifiIP;
      }

      // Fallback to socket method
      return await _getIpUsingSocket();
    } catch (e) {
      debugPrint('Error getting IP address: $e');
      return await _getIpUsingSocket();
    }
  }

  /// Alternative method using socket connection
  Future<String?> _getIpUsingSocket() async {
    try {
      // Connect to a remote address to determine local IP
      final socket = await Socket.connect('8.8.8.8', 80);
      final localAddress = socket.address.address;
      socket.destroy();
      return localAddress;
    } catch (e) {
      debugPrint('Socket method failed: $e');

      // Last resort: check network interfaces
      return await _getIpFromNetworkInterfaces();
    }
  }

  /// Get IP from network interfaces
  Future<String?> _getIpFromNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Look for non-loopback interfaces
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback &&
              !address.isLinkLocal &&
              address.type == InternetAddressType.IPv4) {
            return address.address;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Network interfaces method failed: $e');
      return null;
    }
  }

  /// Check if a specific port is available
  Future<bool> isPortAvailable(int port) async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Find an available port in the given range
  Future<int?> findAvailablePort({int start = 8080, int end = 8090}) async {
    for (int port = start; port <= end; port++) {
      if (await isPortAvailable(port)) {
        return port;
      }
    }
    return null;
  }

  /// Get network interface information
  Future<List<NetworkInterfaceInfo>> getNetworkInterfaces() async {
    final interfaces = await NetworkInterface.list();
    return interfaces.map((interface) {
      return NetworkInterfaceInfo(
        name: interface.name,
        addresses: interface.addresses
            .map(
              (addr) => NetworkAddressInfo(
                address: addr.address,
                type: addr.type.toString(),
                isLoopback: addr.isLoopback,
                isLinkLocal: addr.isLinkLocal,
              ),
            )
            .toList(),
      );
    }).toList();
  }

  /// Test connection to server
  Future<bool> testServerConnection(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
      ).timeout(const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }
}

class NetworkInterfaceInfo {
  final String name;
  final List<NetworkAddressInfo> addresses;

  NetworkInterfaceInfo({required this.name, required this.addresses});
}

class NetworkAddressInfo {
  final String address;
  final String type;
  final bool isLoopback;
  final bool isLinkLocal;

  NetworkAddressInfo({
    required this.address,
    required this.type,
    required this.isLoopback,
    required this.isLinkLocal,
  });
}
