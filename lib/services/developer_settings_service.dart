import 'package:shared_preferences/shared_preferences.dart';

class DeveloperSettingsService {
  static const String _devPassword = 'obo2025';
  static const String _keyDevSmsNumber = 'dev_default_sms_number';
  static const String _keyDevEmail = 'dev_default_email';
  static const String _keyDevEmailCc = 'dev_default_email_cc';
  
  // Default values
  static const String _defaultSmsNumber = '09359483634';
  static const String _defaultEmail = 'anthony.capuyan23@gmail.com';

  /// Verify developer password
  static bool verifyPassword(String password) {
    return password == _devPassword;
  }

  /// Get default SMS number
  static Future<String> getDefaultSmsNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDevSmsNumber) ?? _defaultSmsNumber;
  }

  /// Save default SMS number
  static Future<bool> saveDefaultSmsNumber(String number) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyDevSmsNumber, number);
  }

  /// Get default email recipient
  static Future<String> getDefaultEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDevEmail) ?? _defaultEmail;
  }

  /// Save default email recipient
  static Future<bool> saveDefaultEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyDevEmail, email);
  }

  /// Get default email CC
  static Future<String> getDefaultEmailCc() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDevEmailCc) ?? _defaultEmail;
  }

  /// Save default email CC
  static Future<bool> saveDefaultEmailCc(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyDevEmailCc, email);
  }

  /// Reset to default values
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDevSmsNumber, _defaultSmsNumber);
    await prefs.setString(_keyDevEmail, _defaultEmail);
    await prefs.setString(_keyDevEmailCc, _defaultEmail);
  }
}


