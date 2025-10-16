import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class UrlTester {
  /// Test if the configured API URL is accessible
  static Future<Map<String, dynamic>> testApiUrl() async {
    try {
      // Test with GET first (should return 405 Method Not Allowed)
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/mobile/login.php'),
      ).timeout(const Duration(seconds: 10));
      
      return {
        'success': true,
        'statusCode': response.statusCode,
        'message': response.statusCode == 405 
            ? 'API server is reachable ✅ (405 Method Not Allowed is expected for GET request)'
            : 'API server responded with status ${response.statusCode}',
        'url': '${AppConfig.baseUrl}/mobile/login.php',
        'headers': response.headers,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'url': '${AppConfig.baseUrl}/mobile/login.php',
        'message': 'Failed to connect to API server: $e',
      };
    }
  }
  
  /// Test login endpoint with sample data
  static Future<Map<String, dynamic>> testLoginEndpoint() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/mobile/login.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: '{"username":"test","password":"test","remember":false}',
      ).timeout(const Duration(seconds: 10));
      
      return {
        'success': true,
        'statusCode': response.statusCode,
        'message': 'Login endpoint is accessible',
        'response': response.body,
        'url': '${AppConfig.baseUrl}/mobile/login.php',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'url': '${AppConfig.baseUrl}/mobile/login.php',
        'message': 'Failed to connect to login endpoint',
      };
    }
  }
}
