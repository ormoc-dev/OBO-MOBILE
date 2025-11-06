import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  // Get the current base URL (supports custom IP)
  static Future<String> get baseUrl async => await AppConfig.baseUrl;
  
  // Cookie storage key
  static const String _cookieKey = 'api_session_cookie';
  
  // Get session cookie from storage
  static Future<String?> _getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cookieKey);
    } catch (e) {
      return null;
    }
  }
  
  // Save session cookie to storage
  static Future<void> _saveSessionCookie(String cookie) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cookieKey, cookie);
    } catch (e) {
      print('Error saving session cookie: $e');
    }
  }
  
  // Set session cookie manually (for login)
  static Future<void> setSessionCookie(String cookie) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cookieKey, cookie);
      print('Session cookie manually set: $cookie');
    } catch (e) {
      print('Error setting session cookie: $e');
    }
  }
  
  // Clear session cookie
  static Future<void> clearSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cookieKey);
    } catch (e) {
      print('Error clearing session cookie: $e');
    }
  }
  
  // Extract cookie from Set-Cookie header
  static String? _extractCookieFromHeaders(Map<String, String> headers) {
    // Check all possible cookie header formats
    final setCookie = headers['set-cookie'] ?? 
                      headers['Set-Cookie'] ?? 
                      headers['SET-COOKIE'];
    
    if (setCookie != null) {
      print('Found Set-Cookie header: $setCookie');
      
      // Handle multiple cookies (split by comma)
      final cookies = setCookie.split(',');
      for (var cookie in cookies) {
        cookie = cookie.trim();
        // Extract PHPSESSID or session cookie
        final cookieMatch = RegExp(r'PHPSESSID\s*=\s*([^;]+)').firstMatch(cookie);
        if (cookieMatch != null) {
          final sessionId = cookieMatch.group(1)?.trim();
          if (sessionId != null) {
            return 'PHPSESSID=$sessionId';
          }
        }
      }
      
      // Try to extract any session cookie (fallback)
      final sessionMatch = RegExp(r'([^=\s]+)\s*=\s*([^;]+)').firstMatch(setCookie);
      if (sessionMatch != null) {
        final name = sessionMatch.group(1)?.trim();
        final value = sessionMatch.group(2)?.trim();
        if (name != null && value != null) {
          return '$name=$value';
        }
      }
    }
    
    // Debug: print all headers to see what we're getting
    print('All response headers: $headers');
    return null;
  }
  
  // Get session ID from stored cookie
  static Future<String?> _getSessionId() async {
    final cookie = await _getSessionCookie();
    if (cookie != null) {
      // Extract session ID from PHPSESSID cookie
      final match = RegExp(r'PHPSESSID=([^;]+)').firstMatch(cookie);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }
  
  // Headers for API requests
  static Future<Map<String, String>> get headers async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Add session cookie if available
    final cookie = await _getSessionCookie();
    if (cookie != null) {
      headers['Cookie'] = cookie;
      print('Adding cookie to request: $cookie');
    }
    
    // Also send session ID as header for mobile app support
    final sessionId = await _getSessionId();
    if (sessionId != null) {
      headers['X-Session-Id'] = sessionId;
      print('Adding X-Session-Id header: $sessionId');
    } else {
      print('No session ID available for request');
    }
    
    return headers;
  }

  /// Make HTTP POST request
  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final currentBaseUrl = await baseUrl;
      final requestHeaders = await headers;
      
      print('POST Request to: $currentBaseUrl$endpoint');
      print('Headers: $requestHeaders');
      final bodyJson = jsonEncode(body);
      print('Body length: ${bodyJson.length} characters');
      // Only print body if it's not too large (for debugging)
      if (bodyJson.length < 1000) {
        print('Body: $bodyJson');
      } else {
        print('Body: [Large payload, ${bodyJson.length} characters]');
      }
      
      final response = await http.post(
        Uri.parse('$currentBaseUrl$endpoint'),
        headers: requestHeaders,
        body: bodyJson,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Server took too long to respond');
        },
      );
      
      // Extract and save session cookie from response
      final cookie = _extractCookieFromHeaders(response.headers);
      if (cookie != null) {
        await _saveSessionCookie(cookie);
        print('Session cookie saved from response: $cookie');
      } else {
        // Debug: check if we have a stored cookie
        final storedCookie = await _getSessionCookie();
        print('No cookie in response headers. Stored cookie: $storedCookie');
      }
      
      // Debug: print response headers for troubleshooting
      print('Response headers keys: ${response.headers.keys.toList()}');
      
      return response;
    } catch (e) {
      print('POST Request error: $e');
      print('Error type: ${e.runtimeType}');
      
      // Provide more specific error messages
      String errorMessage = 'Network error occurred';
      if (e.toString().contains('Failed to fetch')) {
        errorMessage = 'Failed to connect to server. Please check your internet connection and server URL.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. The server took too long to respond.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Cannot connect to server. Please check your internet connection.';
      } else {
        errorMessage = 'Network error: $e';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Make HTTP GET request
  static Future<http.Response> get(String endpoint, {Map<String, String>? customHeaders}) async {
    try {
      final currentBaseUrl = await baseUrl;
      final requestHeaders = await headers;
      
      // Merge custom headers
      if (customHeaders != null) {
        requestHeaders.addAll(customHeaders);
      }
      
      final response = await http.get(
        Uri.parse('$currentBaseUrl$endpoint'),
        headers: requestHeaders,
      );
      
      // Extract and save session cookie from response
      final cookie = _extractCookieFromHeaders(response.headers);
      if (cookie != null) {
        await _saveSessionCookie(cookie);
        print('Session cookie saved from response: $cookie');
      } else {
        // Debug: check if we have a stored cookie
        final storedCookie = await _getSessionCookie();
        print('No cookie in response headers. Stored cookie: $storedCookie');
      }
      
      // Debug: print response headers for troubleshooting
      print('Response headers keys: ${response.headers.keys.toList()}');
      
      return response;
    } catch (e) {
      print('GET Request error: $e');
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
