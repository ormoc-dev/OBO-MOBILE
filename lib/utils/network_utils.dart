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
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      // Handle error
    }
    return null;
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
