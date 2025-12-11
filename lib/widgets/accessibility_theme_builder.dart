import 'package:flutter/material.dart';
import '../services/accessibility_service.dart';

class AccessibilityThemeBuilder extends StatelessWidget {
  final Widget child;

  const AccessibilityThemeBuilder({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadAccessibilitySettings(),
      builder: (context, snapshot) {
        final highContrast = snapshot.data?['highContrast'] ?? false;
        final fontScale = snapshot.data?['fontScale'] ?? 1.0;

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: Theme(
            data: _buildTheme(highContrast),
            child: child,
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadAccessibilitySettings() async {
    final highContrast = await AccessibilityService.isHighContrastEnabled();
    final fontScale = await AccessibilityService.getFontScale();
    return {
      'highContrast': highContrast,
      'fontScale': fontScale,
    };
  }

  ThemeData _buildTheme(bool highContrast) {
    if (highContrast) {
      return ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.blue,
          surface: Colors.white,
          background: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black,
          onBackground: Colors.black,
          error: Colors.red,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black, width: 2),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 3),
          ),
        ),
      );
    }

    // Default theme
    return ThemeData(
      primarySwatch: MaterialColor(0xFF086FDE, <int, Color>{
        50: const Color.fromRGBO(8, 111, 222, 0.1),
        100: const Color.fromRGBO(8, 111, 222, 0.2),
        200: const Color.fromRGBO(8, 111, 222, 0.3),
        300: const Color.fromRGBO(8, 111, 222, 0.4),
        400: const Color.fromRGBO(8, 111, 222, 0.5),
        500: const Color.fromRGBO(8, 111, 222, 0.6),
        600: const Color.fromRGBO(8, 111, 222, 0.7),
        700: const Color.fromRGBO(8, 111, 222, 0.8),
        800: const Color.fromRGBO(8, 111, 222, 0.9),
        900: const Color.fromRGBO(8, 111, 222, 1.0),
      }),
      primaryColor: const Color.fromRGBO(8, 111, 222, 0.977),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardColor: Colors.white,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.light(
        primary: Color.fromRGBO(8, 111, 222, 0.977),
        secondary: Color.fromRGBO(8, 111, 222, 0.977),
        surface: Colors.white,
        background: Color(0xFFF8FAFC),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1F2937),
        onBackground: Color(0xFF1F2937),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color.fromRGBO(8, 111, 222, 0.977),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}


