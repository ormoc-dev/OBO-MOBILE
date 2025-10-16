import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'offline_storage.dart';
import 'offline_sync_service.dart';
import 'connectivity_service.dart';

class AuthService {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';
  static const String _rememberKey = 'remember_me';

  /// Login user with username and password
  static Future<LoginResponse> login(String username, String password, {bool remember = false}) async {
    try {
      final connectivityService = ConnectivityService();
      
      // Check if online
      if (connectivityService.isConnected) {
        // Online login
        final request = LoginRequest(
          username: username,
          password: password,
          remember: remember,
        );

        final response = await ApiService.post('/mobile/login.php', request.toJson());
        final responseData = ApiService.handleResponse(response);
        
        final loginResponse = LoginResponse.fromJson(responseData);
        
        if (loginResponse.success && loginResponse.data != null) {
          // Store user data and session
          await _storeUserSession(loginResponse.data!.user, remember);
          // Save to offline storage
          await OfflineStorage.saveUser(loginResponse.data!.user);
        }
        
        return loginResponse;
      } else {
        // Offline login - check if user exists in offline sync data
        final offlineUser = await OfflineSyncService.authenticateOffline(username, password);
        if (offlineUser != null) {
          // User found in offline sync data
          await _storeUserSession(offlineUser, remember);
          return LoginResponse(
            success: true,
            message: 'Logged in offline',
            data: LoginData(
              user: offlineUser,
              sessionId: 'offline_session',
              mobileApp: true,
            ),
          );
        } else {
          // Fallback to old offline storage
          final oldOfflineUser = await OfflineStorage.getCurrentUser();
          if (oldOfflineUser != null && oldOfflineUser.name == username) {
            await _storeUserSession(oldOfflineUser, remember);
            return LoginResponse(
              success: true,
              message: 'Logged in offline (cached)',
              data: LoginData(
                user: oldOfflineUser,
                sessionId: 'offline_session',
                mobileApp: true,
              ),
            );
          } else {
            throw Exception('No offline data available. Please connect to internet and sync data first.');
          }
        }
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  /// Logout user (keeps offline data for offline login)
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_rememberKey);
      
      // Don't clear offline data - keep synced assignments and credentials for offline use
      // Only clear the current session data
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  /// Complete logout - clears all data including offline sync data
  static Future<void> logoutAndClearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_rememberKey);
      
      // Clear all offline data including synced assignments and credentials
      await OfflineStorage.clearUser();
      await OfflineSyncService.clearAllOfflineData();
    } catch (e) {
      throw Exception('Complete logout failed: $e');
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_userKey);
    } catch (e) {
      return false;
    }
  }

  /// Get current user data
  static Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Store user session data
  static Future<void> _storeUserSession(User user, bool remember) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store user data
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
      
      // Store remember me preference
      await prefs.setBool(_rememberKey, remember);
      
      // Generate and store a simple token (you can enhance this)
      final token = base64Encode(utf8.encode('${user.id}:${DateTime.now().millisecondsSinceEpoch}'));
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      throw Exception('Failed to store session: $e');
    }
  }

  /// Get stored auth token
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Check if remember me is enabled
  static Future<bool> isRememberMeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_rememberKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Validate stored session
  static Future<bool> validateSession() async {
    try {
      final user = await getCurrentUser();
      final token = await getAuthToken();
      
      if (user == null || token == null) {
        return false;
      }
      
      // You can add additional validation here, such as:
      // - Checking token expiration
      // - Validating with server
      // - Checking user status
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
