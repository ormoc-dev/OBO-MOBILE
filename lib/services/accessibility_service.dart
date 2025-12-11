import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityService {
  static const String _keyHighContrast = 'high_contrast_mode';
  static const String _keyFontScale = 'font_scale';
  static const double _defaultFontScale = 1.0;
  static const double _minFontScale = 0.8;
  static const double _maxFontScale = 2.0;

  /// Check if high contrast mode is enabled
  static Future<bool> isHighContrastEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyHighContrast) ?? false;
    } catch (e) {
      print('Error checking high contrast mode: $e');
      return false;
    }
  }

  /// Toggle high contrast mode
  static Future<void> setHighContrast(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHighContrast, enabled);
    } catch (e) {
      print('Error setting high contrast mode: $e');
    }
  }

  /// Get current font scale
  static Future<double> getFontScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scale = prefs.getDouble(_keyFontScale);
      if (scale == null) return _defaultFontScale;
      // Clamp between min and max
      return scale.clamp(_minFontScale, _maxFontScale);
    } catch (e) {
      print('Error getting font scale: $e');
      return _defaultFontScale;
    }
  }

  /// Set font scale
  static Future<void> setFontScale(double scale) async {
    try {
      // Clamp between min and max
      final clampedScale = scale.clamp(_minFontScale, _maxFontScale);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyFontScale, clampedScale);
    } catch (e) {
      print('Error setting font scale: $e');
    }
  }

  /// Reset to defaults
  static Future<void> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHighContrast);
      await prefs.remove(_keyFontScale);
    } catch (e) {
      print('Error resetting accessibility settings: $e');
    }
  }

  static double get minFontScale => _minFontScale;
  static double get maxFontScale => _maxFontScale;
  static double get defaultFontScale => _defaultFontScale;
}


