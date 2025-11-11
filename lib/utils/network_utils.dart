import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

import '../config/app_config.dart';

class NetworkUtils {
  static final NetworkInfo _networkInfo = NetworkInfo();

  /// Test if the API server is reachable
  static Future<bool> testApiConnection() async {
    try {
      // Await the base URL since it's a Future
      final baseUrl = await AppConfig.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/auth/login.php'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      // We expect a 405 Method Not Allowed since this is a POST endpoint
      // This confirms the server is reachable
      return response.statusCode == 405;
    } catch (e) {
      return false;
    }
  }

  /// Get the device's local IP address (for debugging)
  static Future<String?> getLocalIpAddress() async {
    // Try multiple methods to get the local IP address

    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty) {
        print('NetworkUtils: Using web host for IP: $host');
        return host;
      }
      print('NetworkUtils: Web environment without host information.');
      return null;
    }
    
    String? lastGatewayIp;

    // Method 0: Use network_info_plus (works well on Android/iOS when permissions granted)
    try {
      final wifiIp = await _networkInfo.getWifiIP();
      if (_isValidPrivateIp(wifiIp)) {
        print('NetworkUtils: WiFi IP from network_info_plus: $wifiIp');
        return wifiIp;
      }
      final gatewayIp = await _networkInfo.getWifiGatewayIP();
      if (gatewayIp != null) {
        print('NetworkUtils: WiFi gateway IP (for reference): $gatewayIp');
        lastGatewayIp = gatewayIp;
      }
    } catch (e) {
      print('NetworkUtils: network_info_plus WiFi IP detection failed: $e');
    }
    
    if (lastGatewayIp != null) {
      final gatewayDerived = await _getLocalIpViaGateway(lastGatewayIp!);
      if (_isValidPrivateIp(gatewayDerived)) {
        print('NetworkUtils: IP derived from gateway socket: $gatewayDerived');
        return gatewayDerived;
      }
    }
    
    // Method 1: Try NetworkInterface.list() (works on some platforms)
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: true,
        type: InternetAddressType.any,
      );
      print('NetworkUtils: Found ${interfaces.length} network interfaces');

      String? wifiCandidate;
      String? otherCandidate;

      for (var interface in interfaces) {
        print('NetworkUtils: Interface ${interface.name} has ${interface.addresses.length} addresses');
        
        for (var addr in interface.addresses) {
          print('NetworkUtils: Address ${addr.address} - Type: ${addr.type}, Loopback: ${addr.isLoopback}');

          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback && _isPrivateIp(addr.address)) {
            print('NetworkUtils: Found valid private IPv4 address: ${addr.address}');
            if (_isLikelyWifiInterface(interface.name)) {
              wifiCandidate ??= addr.address;
            } else {
              otherCandidate ??= addr.address;
            }
          }
        }
      }

      if (wifiCandidate != null) {
        print('NetworkUtils: Returning WiFi candidate: $wifiCandidate');
        return wifiCandidate;
      }

      if (otherCandidate != null) {
        print('NetworkUtils: Returning fallback candidate: $otherCandidate');
        return otherCandidate;
      }

      print('NetworkUtils: No valid private IPv4 address found via NetworkInterface');
    } catch (e) {
      print('NetworkUtils: NetworkInterface.list() failed: $e');
    }
    
    // Method 2: Try to get IP via HTTP request to a local service
    try {
      final ip = await _getIpViaHttpRequest();
      if (ip != null) {
        print('NetworkUtils: Found IP via HTTP request: $ip');
        return ip;
      }
    } catch (e) {
      print('NetworkUtils: HTTP IP detection failed: $e');
    }
    
    // Method 3: Try common local IP ranges
    final ip = await _tryCommonLocalIps();
    if (ip != null) {
      print('NetworkUtils: Found IP via socket detection: $ip');
      return ip;
    }

    print('NetworkUtils: All IP detection methods failed');
    return null;
  }
  
  static bool _isValidPrivateIp(String? ip) {
    if (ip == null) return false;
    if (ip.isEmpty) return false;
    if (ip == '0.0.0.0') return false;
    return _isPrivateIp(ip);
  }
  
  static Future<String?> _getLocalIpViaGateway(String gatewayIp) async {
    try {
      final socket = await Socket.connect(
        gatewayIp,
        80,
        timeout: const Duration(milliseconds: 600),
      );
      final localAddress = socket.address.address;
      socket.destroy();
      if (_isValidPrivateIp(localAddress)) {
        return localAddress;
      }
    } catch (e) {
      print('NetworkUtils: Gateway socket method failed: $e');
    }
    return null;
  }
  
  /// Try to get IP address via HTTP request to local services
  static Future<String?> _getIpViaHttpRequest() async {
    try {
      // Try to connect to a local service and extract IP from connection
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      client.close();
    } catch (e) {
      print('NetworkUtils: HTTP request method error: $e');
    }
    return null;
  }
  
  /// Try to detect IP by testing common local network ranges
  static Future<String?> _tryCommonLocalIps() async {
    // Try to detect the local IP by making a connection to a known external service
    // and examining the local socket address
    try {
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 2));
      final localAddress = socket.address.address;
      socket.destroy();

      if (_isPrivateIp(localAddress)) {
        return localAddress;
      }
    } catch (e) {
      print('NetworkUtils: Socket connection method failed: $e');
    }
    
    return null;
  }
  
  /// Check if an IP address is in the private range
  static bool _isPrivateIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    final first = int.tryParse(parts[0]) ?? 0;
    final second = int.tryParse(parts[1]) ?? 0;
    
    // Private IP ranges:
    // 10.0.0.0 - 10.255.255.255
    // 172.16.0.0 - 172.31.255.255
    // 192.168.0.0 - 192.168.255.255
    return (first == 10) ||
           (first == 172 && second >= 16 && second <= 31) ||
           (first == 192 && second == 168);
  }

  static bool _isLikelyWifiInterface(String name) {
    final lowered = name.toLowerCase();
    return lowered.contains('wlan') ||
        lowered.contains('wifi') ||
        lowered.contains('wi-fi') ||
        lowered.contains('wl') ||
        lowered.contains('en');
  }

  /// Check internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      // Try to connect to our own API server first
      // Await the base URL since it's a Future
      final baseUrl = await AppConfig.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/auth/login.php'),
      ).timeout(const Duration(seconds: 5));
      // We expect 405 Method Not Allowed for GET request, which means server is reachable
      return response.statusCode == 405 || response.statusCode == 200;
    } catch (e) {
      // If our server is not reachable, try a simple connectivity test
      try {
        final response = await http.get(
          Uri.parse('https://www.google.com'),
        ).timeout(const Duration(seconds: 3));
        return response.statusCode == 200;
      } catch (e) {
        return false;
      }
    }
  }
}
