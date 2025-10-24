import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiService {
  // Get the current base URL (supports custom IP)
  static Future<String> get baseUrl async => await AppConfig.baseUrl;
  
  // Headers for API requests
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Make HTTP POST request
  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.post(
        Uri.parse('$currentBaseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return response;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Make HTTP GET request
  static Future<http.Response> get(String endpoint, {Map<String, String>? customHeaders}) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl$endpoint'),
        headers: {...headers, ...?customHeaders},
      );
      return response;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Handle API response and return parsed data
  static Map<String, dynamic> handleResponse(http.Response response) {
    print('API Response Status: ${response.statusCode}');
    print('API Response Body: ${response.body}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final data = jsonDecode(response.body);
        print('Parsed JSON: $data');
        return data;
      } catch (e) {
        print('JSON Parse Error: $e');
        throw Exception('Invalid JSON response: ${response.body}');
      }
    } else {
      print('HTTP Error: ${response.statusCode} - ${response.body}');
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Check if device is connected to internet
  static Future<bool> isConnected() async {
    try {
      // Try to connect to our own API server first
      final response = await http.get(
        Uri.parse('$baseUrl/mobile/login.php'),
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
