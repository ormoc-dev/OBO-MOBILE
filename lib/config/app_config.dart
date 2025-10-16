class AppConfig {
  // API Configuration
  // IMPORTANT: Update this URL to match your XAMPP server setup
  
  // For local development, you have several options:
  
  // Option 1: If testing on Android emulator, use 10.0.2.2 (maps to host machine's localhost)
  // static const String baseUrl = 'http://10.0.2.2/OBO-LGU/api';
  
  // Option 2: For physical device, use your computer's IP address (192.168.0.152)
  // static const String baseUrl = 'http://192.168.0.152/OBO-LGU/api';
  
  // For Chrome/Edge testing, use localhost with port 80
  // static const String baseUrl = 'http://localhost/OBO-LGU/api';
  
  // For APK builds, use your computer's IP address
  static const String baseUrl = 'http://192.168.0.152/OBO-LGU/api';
  
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
