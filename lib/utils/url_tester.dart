import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class UrlTester {
  /// Test if the configured API URL is accessible
  static Future<Map<String, dynamic>> testApiUrl() async {
    try {
      // Await the base URL since it's a Future
      final baseUrl = await AppConfig.baseUrl;
      final testUrl = '$baseUrl/mobile/login.php';
      
      // Test with GET first (should return 405 Method Not Allowed)
      final response = await http.get(
        Uri.parse(testUrl),
      ).timeout(const Duration(seconds: 10));
      
      return {
        'success': true,
        'statusCode': response.statusCode,
        'message': response.statusCode == 405 
            ? 'API server is reachable ✅ (405 Method Not Allowed is expected for GET request)'
            : 'API server responded with status ${response.statusCode}',
        'url': testUrl,
        'headers': response.headers,
      };
    } catch (e) {
      // Await the base URL even in error case
      final baseUrl = await AppConfig.baseUrl;
      final testUrl = '$baseUrl/mobile/login.php';
      
      return {
        'success': false,
        'error': e.toString(),
        'url': testUrl,
        'message': 'Failed to connect to API server: $e',
      };
    }
  }
  
  /// Test login endpoint with sample data
  static Future<Map<String, dynamic>> testLoginEndpoint() async {
    try {
      // Await the base URL since it's a Future
      final baseUrl = await AppConfig.baseUrl;
      final testUrl = '$baseUrl/mobile/login.php';
      
      final response = await http.post(
        Uri.parse(testUrl),
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
        'url': testUrl,
      };
    } catch (e) {
      // Await the base URL even in error case
      final baseUrl = await AppConfig.baseUrl;
      final testUrl = '$baseUrl/mobile/login.php';
      
      return {
        'success': false,
        'error': e.toString(),
        'url': testUrl,
        'message': 'Failed to connect to login endpoint',
      };
    }
  }
}
