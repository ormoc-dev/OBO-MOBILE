import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // API Configuration
  // IMPORTANT: Update this URL to match your XAMPP server setup
  
  // Default base URL (fallback)
  static const String _defaultBaseUrl = 'http://172.31.208.1/OBO-LGU/api';
  
  // Get the current base URL (checks for custom IP first)
  static Future<String> get baseUrl async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customBaseUrl = prefs.getString('custom_base_url');
      return customBaseUrl ?? _defaultBaseUrl;
    } catch (e) {
      return _defaultBaseUrl;
    }
  }
  
  // Get the default base URL (for display purposes)
  static String get defaultBaseUrl => _defaultBaseUrl;
  
  // Option 2: If testing on physical device, use your computer's IP address
  // Find your IP address by running 'ipconfig' in Command Prompt (Windows) or 'ifconfig' in Terminal (Mac/Linux)
  // Example: static const String baseUrl = 'http://192.168.1.100/OBO-LGU/api';
  
  // Option 3: If using localhost for web development
  // static const String baseUrl = 'http://localhost/OBO-LGU/api';
  
  // Option 4: If using a different port for XAMPP
  // static const String baseUrl = 'http://localhost:8080/OBO-LGU/api';
  
  // Mobile-specific API Endpoints
  static const String loginEndpoint = '/mobile/login.php';
  static const String logoutEndpoint = '/mobile/logout.php';
  static const String checkSessionEndpoint = '/mobile/check_session.php';
  static const String getAssignmentsEndpoint = '/mobile/get_assignments.php';
  
  // App Configuration
  static const String appName = 'OBO Inspector Mobile';
  static const String appVersion = '1.0.0';
  
  // Session Configuration
  static const int sessionTimeoutMinutes = 30;
  static const bool enableRememberMe = true;
  
  // Debug Configuration
  static const bool enableDebugLogs = true;
  static const bool enableNetworkLogs = true;
}

// Helper class for network configuration
class NetworkConfig {
  static const int connectionTimeout = 30; // seconds
  static const int receiveTimeout = 30; // seconds
  static const int sendTimeout = 30; // seconds
  
  // Retry configuration
  static const int maxRetries = 3;
  static const int retryDelay = 1000; // milliseconds
}
