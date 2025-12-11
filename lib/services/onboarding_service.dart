import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyOnboardingVersion = 'onboarding_version';
  static const int _currentOnboardingVersion = 1;

  /// Check if user has completed onboarding
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_keyOnboardingCompleted) ?? false;
      final version = prefs.getInt(_keyOnboardingVersion) ?? 0;
      
      print('OnboardingService: Checking status - completed: $completed, version: $version (current: $_currentOnboardingVersion)');
      
      // If onboarding version changed, show onboarding again
      if (version < _currentOnboardingVersion) {
        print('OnboardingService: Version mismatch, showing onboarding');
        return false;
      }
      
      print('OnboardingService: Status - ${completed ? "COMPLETED" : "NOT COMPLETED"}');
      return completed;
    } catch (e) {
      print('Error checking onboarding status: $e');
      return false;
    }
  }

  /// Mark onboarding as completed
  static Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, true);
      await prefs.setInt(_keyOnboardingVersion, _currentOnboardingVersion);
      print('OnboardingService: Marked as completed (version $_currentOnboardingVersion)');
    } catch (e) {
      print('Error completing onboarding: $e');
    }
  }

  /// Reset onboarding (for testing or if you want to show it again)
  static Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyOnboardingCompleted);
      await prefs.remove(_keyOnboardingVersion);
      print('OnboardingService: Reset onboarding - will show on next app start');
    } catch (e) {
      print('Error resetting onboarding: $e');
    }
  }

  /// Get current onboarding version
  static int get currentVersion => _currentOnboardingVersion;
}

