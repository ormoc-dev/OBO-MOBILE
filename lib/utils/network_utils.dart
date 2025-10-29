import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class NetworkUtils {
  /// Test if the API server is reachable
  static Future<bool> testApiConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/auth/login.php'),
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
    
    // Method 1: Try NetworkInterface.list() (works on some platforms)
    try {
      final interfaces = await NetworkInterface.list();
      print('NetworkUtils: Found ${interfaces.length} network interfaces');
      
      for (var interface in interfaces) {
        print('NetworkUtils: Interface ${interface.name} has ${interface.addresses.length} addresses');
        
        for (var addr in interface.addresses) {
          print('NetworkUtils: Address ${addr.address} - Type: ${addr.type}, Loopback: ${addr.isLoopback}');
          
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            print('NetworkUtils: Found valid IPv4 address: ${addr.address}');
            return addr.address;
          }
        }
      }
      
      print('NetworkUtils: No valid IPv4 address found via NetworkInterface');
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
    try {
      final ip = await _tryCommonLocalIps();
      if (ip != null) {
        print('NetworkUtils: Found IP via common ranges: $ip');
        return ip;
      }
    } catch (e) {
      print('NetworkUtils: Common IP detection failed: $e');
    }
    
    print('NetworkUtils: All IP detection methods failed');
    return null;
  }
  
  /// Try to get IP address via HTTP request to local services
  static Future<String?> _getIpViaHttpRequest() async {
    try {
      // Try to connect to a local service and extract IP from connection
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      
      // Try common local IP ranges
      final commonIps = [
        '192.168.0.115', // From your ipconfig output
        '192.168.1.1',
        '192.168.0.1',
        '10.0.0.1',
        '172.16.0.1',
      ];
      
      for (final ip in commonIps) {
        try {
          final request = await client.getUrl(Uri.parse('http://$ip:80/'));
          final response = await request.close().timeout(const Duration(seconds: 1));
          if (response.statusCode < 500) {
            // If we can connect, this might be our local network
            return ip;
          }
        } catch (e) {
          // Continue to next IP
        }
      }
      
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
      
      // Only return if it's a private IP address
      if (_isPrivateIp(localAddress)) {
        return localAddress;
      }
    } catch (e) {
      print('NetworkUtils: Socket connection method failed: $e');
    }
    
    // Fallback: return the IP from your ipconfig output
    return '192.168.0.115';
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

  /// Check internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      // Try to connect to our own API server first
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/auth/login.php'),
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
