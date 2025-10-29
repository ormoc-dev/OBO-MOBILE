import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/hive_offline_database.dart';
import 'screens/dashboard_screen.dart';
import 'screens/debug_screen.dart';
import 'utils/asset_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize connectivity service
  await ConnectivityService().initialize();
  
  // Initialize Hive database and handle migration
  await _initializeDatabase();
  
  runApp(const MyApp());
}

Future<void> _initializeDatabase() async {
  try {
    // Initialize Hive database directly
    await HiveOfflineDatabase.initialize();
    print('Hive database initialized successfully');
  } catch (e) {
    print('Error initializing database: $e');
    // Continue with app initialization even if database fails
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBO Inspector Mobile',
      theme: ThemeData(
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
        primaryColor: const Color.fromRGBO(8, 111, 222, 0.977), // Requested blue
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Clean white background
        cardColor: Colors.white,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.light(
          primary: Color.fromRGBO(8, 111, 222, 0.977),
          secondary: Color.fromRGBO(8, 111, 222, 0.977),
          surface: Colors.white,
          background: Color(0xFFF8FAFC),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1F2937), // Dark gray text
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
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isLoading = true;
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();
      final validSession = await AuthService.validateSession();
      
      setState(() {
        isLoggedIn = loggedIn && validSession;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoggedIn = false;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return isLoggedIn ? const DashboardScreen() : const WelcomePage();
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final orientation = MediaQuery.of(context).orientation;
    
    // Enhanced responsive breakpoints
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
    // Dynamic scaling based on screen size and orientation
    // Adjust base height for better tablet scaling
    final double baseHeight = isLandscape ? 600.0 : (isLargeTablet ? 1000.0 : 800.0);
    final double scale = (screenHeight / baseHeight).clamp(0.6, 1.2);
    
    // Additional scaling for very small screens
    final double smallScreenScale = isVerySmallScreen ? 0.8 : 1.0;
    final double finalScale = scale * smallScreenScale;
    
    // Enhanced responsive dimensions with better breakpoints (same as dashboard)
    final logoSize = (isLargeTablet ? 120.0 : (isTablet ? 100.0 : (isVerySmallScreen ? 50.0 : (isSmallScreen ? 60.0 : 80.0)))) * finalScale;
    final logoFontSize = (isLargeTablet ? 120.0 : (isTablet ? 100.0 : (isVerySmallScreen ? 50.0 : (isSmallScreen ? 60.0 : 80.0)))) * finalScale;
    final titleFontSize = (isLargeTablet ? 28.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 20.0)))) * finalScale;
    final descriptionFontSize = (isLargeTablet ? 22.0 : (isTablet ? 19.0 : (isVerySmallScreen ? 13.0 : (isSmallScreen ? 15.0 : 17.0)))) * finalScale;
    final buttonHeight = (isLargeTablet ? 80.0 : (isTablet ? 70.0 : (isVerySmallScreen ? 45.0 : (isSmallScreen ? 50.0 : 65.0)))) * finalScale;
    final secondaryButtonHeight = (isLargeTablet ? 70.0 : (isTablet ? 60.0 : (isVerySmallScreen ? 40.0 : (isSmallScreen ? 45.0 : 55.0)))) * finalScale;
    // Improved responsive padding for better tablet centering
    final horizontalPadding = isLargeTablet 
        ? screenWidth * 0.08  // 8% of screen width for large tablets
        : isTablet 
            ? screenWidth * 0.12  // 12% of screen width for tablets
            : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 20.0 : 32.0)) * finalScale;
    final verticalSpacing = (isVerySmallScreen ? 15.0 : (isSmallScreen ? 20.0 : 30.0)) * finalScale;
    
    // Additional responsive dimensions for better control
    final iconSize = (isLargeTablet ? 24.0 : (isTablet ? 20.0 : (isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 18.0)))) * finalScale;
    final versionFontSize = (isLargeTablet ? 18.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 10.0 : (isSmallScreen ? 12.0 : 14.0)))) * finalScale;
    final featureFontSize = (isLargeTablet ? 20.0 : (isTablet ? 18.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0)))) * finalScale;
    
    // Landscape-specific adjustments
    final landscapePadding = isLandscape ? (screenWidth * 0.1) : horizontalPadding;
    final landscapeVerticalSpacing = isLandscape ? (verticalSpacing * 0.7) : verticalSpacing;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC), // Clean white
              Color(0xFFF1F5F9), // Light gray
              Color(0xFFE2E8F0), // Slightly darker gray
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? landscapePadding : horizontalPadding, 
              vertical: isLandscape ? 8.0 * finalScale : 12.0 * finalScale
            ),
            child: isLandscape ? _buildLandscapeLayout(
              context, screenWidth, screenHeight, finalScale, 
              logoSize, logoFontSize, titleFontSize, descriptionFontSize,
              buttonHeight, secondaryButtonHeight, landscapeVerticalSpacing,
              isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen
            ) : Column(
              children: [
                // Fixed Ormoc Banner at top
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: (isLargeTablet ? 16.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 10.0)))) * finalScale, 
                    vertical: (isLargeTablet ? 8.0 : (isTablet ? 6.0 : (isVerySmallScreen ? 3.0 : (isSmallScreen ? 4.0 : 5.0)))) * finalScale
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AssetHelper.loadOrmocBanner(
                      width: (isLargeTablet ? 200.0 : (isTablet ? 160.0 : (isVerySmallScreen ? 100.0 : (isSmallScreen ? 120.0 : 140.0)))) * finalScale,
                      height: (isLargeTablet ? 60.0 : (isTablet ? 50.0 : (isVerySmallScreen ? 30.0 : (isSmallScreen ? 35.0 : 40.0)))) * finalScale,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 120,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isTablet ? 600 : double.infinity,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                    SizedBox(height: isSmallScreen ? 10 : 20),
                    // Logo + BO text combined
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                        // Logo as the "O"
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(8, 111, 222, 0.977),
                            borderRadius: BorderRadius.circular(logoSize / 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFFE2E8F0),
                                offset: Offset(0, 4),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(logoSize / 2),
                            child: AssetHelper.loadOrmocSeal(
                              width: logoSize * 0.620, // 5/8 of container size
                              height: logoSize * 0.620,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(width: (isLargeTablet ? 16.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 8.0)))) * finalScale),
                        // BO text
                        Text(
                          'BO',
                          style: TextStyle(
                            fontSize: logoFontSize,
                            fontWeight: FontWeight.w900,
                            color: const Color.fromRGBO(8, 111, 222, 0.977),
                            letterSpacing: 2,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                    SizedBox(height: verticalSpacing),
                    // Simple subtitle without neumorphism
                    Center(
                      child: Text(
                        'Office of Building Official',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          color: const Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: verticalSpacing),
                    // Description + Key features checklist
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: const Color.fromRGBO(8, 111, 222, 0.977),
                                    size: iconSize,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Assign, track, and complete inspections with clear status updates',
                                      style: TextStyle(
                                        fontSize: featureFontSize,
                                        color: const Color(0xFF1F2937),
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: const Color.fromRGBO(8, 111, 222, 0.977),
                                    size: iconSize,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'QR code scanning for fast record lookup and verification',
                                      style: TextStyle(
                                        fontSize: featureFontSize,
                                        color: const Color(0xFF1F2937),
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: const Color.fromRGBO(8, 111, 222, 0.977),
                                    size: iconSize,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Offline-first design with secure local storage and one-tap sync',
                                      style: TextStyle(
                                        fontSize: featureFontSize,
                                        color: const Color(0xFF1F2937),
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: const Color.fromRGBO(8, 111, 222, 0.977),
                                    size: iconSize,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Modern, clean UI built for tablets and small screens',
                                      style: TextStyle(
                                        fontSize: featureFontSize,
                                        color: const Color(0xFF1F2937),
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: (isLargeTablet ? 32.0 : (isTablet ? 28.0 : (isVerySmallScreen ? 20.0 : (isSmallScreen ? 24.0 : 30.0)))) * finalScale),
                    // Enhanced Get Started Button
                    Container(
                      width: double.infinity,
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(8, 111, 222, 0.977),
                        borderRadius: BorderRadius.circular(buttonHeight / 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFE2E8F0),
                            offset: Offset(0, 4),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(buttonHeight / 2),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Get Started',
                                  style: TextStyle(
                                    fontSize: (isLargeTablet ? 24.0 : (isTablet ? 22.0 : (isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 20.0)))) * finalScale,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(width: (isLargeTablet ? 20.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)))) * finalScale),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: (isLargeTablet ? 32.0 : (isTablet ? 28.0 : (isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 24.0)))) * finalScale,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: (isLargeTablet ? 16.0 : (isTablet ? 14.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)))) * finalScale),
                    // Enhanced Secondary button
                    Container(
                      width: double.infinity,
                      height: secondaryButtonHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(secondaryButtonHeight / 2),
                        border: Border.all(color: const Color.fromRGBO(8, 111, 222, 0.977), width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFE2E8F0),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(secondaryButtonHeight / 2),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DebugScreen(),
                              ),
                            );
                          },
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.settings_outlined,
                                  color: const Color.fromRGBO(8, 111, 222, 0.977),
                                  size: (isLargeTablet ? 28.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0)))) * finalScale,
                                ),
                                SizedBox(width: (isLargeTablet ? 16.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 8.0)))) * finalScale),
                                Text(
                                  'Debug & Setup',
                                  style: TextStyle(
                                    fontSize: (isLargeTablet ? 21.0 : (isTablet ? 19.0 : (isVerySmallScreen ? 13.0 : (isSmallScreen ? 15.0 : 17.0)))) * finalScale,
                                    fontWeight: FontWeight.w600,
                                    color: const Color.fromRGBO(8, 111, 222, 0.977),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: (isLargeTablet ? 20.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 18.0)))) * finalScale),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Fixed version number at bottom
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: (isLargeTablet ? 16.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 10.0)))) * finalScale, 
                    vertical: (isLargeTablet ? 8.0 : (isTablet ? 6.0 : (isVerySmallScreen ? 3.0 : (isSmallScreen ? 4.0 : 5.0)))) * finalScale
                  ),
                
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'v0.2.0',
                      style: TextStyle(
                        fontSize: versionFontSize,
                        color: const Color.fromRGBO(8, 111, 222, 0.977),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    double screenWidth,
    double screenHeight,
    double scale,
    double logoSize,
    double logoFontSize,
    double titleFontSize,
    double descriptionFontSize,
    double buttonHeight,
    double secondaryButtonHeight,
    double verticalSpacing,
    bool isTablet,
    bool isLargeTablet,
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    return Column(
      children: [
        // Fixed Ormoc Banner at top for landscape
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: (isLargeTablet ? 16.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 10.0)))) * scale, 
            vertical: (isLargeTablet ? 8.0 : (isTablet ? 6.0 : (isVerySmallScreen ? 3.0 : (isSmallScreen ? 4.0 : 5.0)))) * scale
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AssetHelper.loadOrmocBanner(
              width: (isLargeTablet ? 200.0 : (isTablet ? 160.0 : (isVerySmallScreen ? 100.0 : (isSmallScreen ? 120.0 : 140.0)))) * scale,
              height: (isLargeTablet ? 60.0 : (isTablet ? 50.0 : (isVerySmallScreen ? 30.0 : (isSmallScreen ? 35.0 : 40.0)))) * scale,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20 * scale),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 600 : double.infinity,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
            // Logo + BO text
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Container(
                  width: logoSize * 0.8,
                  height: logoSize * 0.8,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(8, 111, 222, 0.977),
                    borderRadius: BorderRadius.circular(logoSize * 0.4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFE2E8F0),
                        offset: Offset(0, 4),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(logoSize * 0.4),
                    child: AssetHelper.loadOrmocSeal(
                      width: logoSize * 0.5,
                      height: logoSize * 0.5,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'BO',
                  style: TextStyle(
                    fontSize: logoFontSize * 0.8,
                    fontWeight: FontWeight.w900,
                    color: const Color.fromRGBO(8, 111, 222, 0.977),
                    letterSpacing: 2,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
            SizedBox(height: verticalSpacing * 0.5),
            Center(
              child: Text(
                'Office of Building Official',
                style: TextStyle(
                  fontSize: titleFontSize * 0.8,
                  color: const Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: verticalSpacing),
            Text(
              'Mobile application for building inspectors to efficiently manage inspections, track compliance, and streamline official processes across the field and office.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: descriptionFontSize * 0.9,
                color: const Color(0xFF6B7280),
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: verticalSpacing),
            // Buttons in landscape
            Container(
              width: double.infinity,
              height: buttonHeight * 0.8,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(8, 111, 222, 0.977),
                borderRadius: BorderRadius.circular(buttonHeight * 0.4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFE2E8F0),
                    offset: Offset(0, 4),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(buttonHeight * 0.4),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: titleFontSize * 0.6,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: titleFontSize * 0.7,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: verticalSpacing * 0.5),
            Container(
              width: double.infinity,
              height: secondaryButtonHeight * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(secondaryButtonHeight * 0.4),
                border: Border.all(color: const Color.fromRGBO(8, 111, 222, 0.977), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFE2E8F0),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(secondaryButtonHeight * 0.4),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DebugScreen(),
                      ),
                    );
                  },
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: const Color.fromRGBO(8, 111, 222, 0.977),
                          size: titleFontSize * 0.6,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Debug & Setup',
                          style: TextStyle(
                            fontSize: titleFontSize * 0.5,
                            fontWeight: FontWeight.w600,
                            color: const Color.fromRGBO(8, 111, 222, 0.977),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: verticalSpacing),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Fixed version number at bottom for landscape
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: (isLargeTablet ? 16.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 10.0)))) * scale, 
            vertical: (isLargeTablet ? 8.0 : (isTablet ? 6.0 : (isVerySmallScreen ? 3.0 : (isSmallScreen ? 4.0 : 5.0)))) * scale
          ),
       
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'v0.2.0',
              style: TextStyle(
                fontSize: (isLargeTablet ? 18.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 10.0 : (isSmallScreen ? 12.0 : 14.0)))) * scale,
                color: const Color.fromRGBO(8, 111, 222, 0.977),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String _connectivityStatus = 'Checking connection...';
  bool _isConnected = false;
  bool _hasSyncedData = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivityStatus();
  }

  Future<void> _checkConnectivityStatus() async {
    try {
      final status = await AuthService.checkConnectivityAndSyncStatus();
      final message = await AuthService.getLoginStatusMessage();
      
      setState(() {
        _isConnected = status.isConnected;
        _hasSyncedData = status.hasSyncedData;
        _connectivityStatus = message;
      });
    } catch (e) {
      setState(() {
        _connectivityStatus = 'Error checking connection: $e';
        _isConnected = false;
        _hasSyncedData = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await AuthService.login(
        _usernameController.text.trim(),
        _passwordController.text,
        remember: _rememberMe,
      );

      if (response.success) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final orientation = MediaQuery.of(context).orientation;
    
    // Enhanced responsive breakpoints
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
    // Dynamic scaling based on screen size and orientation
    // Adjust base height for better tablet scaling
    final double baseHeight = isLandscape ? 600.0 : (isLargeTablet ? 1000.0 : 800.0);
    final double scale = (screenHeight / baseHeight).clamp(0.6, 1.2);
    final double smallScreenScale = isVerySmallScreen ? 0.8 : 1.0;
    final double finalScale = scale * smallScreenScale;
    
    // Enhanced responsive dimensions
    final backButtonSize = (isLargeTablet ? 75.0 : (isTablet ? 65.0 : (isVerySmallScreen ? 40.0 : (isSmallScreen ? 45.0 : 55.0)))) * finalScale;
    final titleFontSize = (isLargeTablet ? 48.0 : (isTablet ? 42.0 : (isVerySmallScreen ? 24.0 : (isSmallScreen ? 28.0 : 36.0)))) * finalScale;
    final subtitleFontSize = (isLargeTablet ? 22.0 : (isTablet ? 19.0 : (isVerySmallScreen ? 13.0 : (isSmallScreen ? 15.0 : 17.0)))) * finalScale;
    final buttonHeight = (isLargeTablet ? 80.0 : (isTablet ? 70.0 : (isVerySmallScreen ? 45.0 : (isSmallScreen ? 50.0 : 65.0)))) * finalScale;
    final horizontalPadding = (isLargeTablet ? 80.0 : (isTablet ? 60.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 20.0 : 32.0)))) * finalScale;
    final fieldSpacing = (isVerySmallScreen ? 15.0 : (isSmallScreen ? 20.0 : 28.0)) * finalScale;
    
    // Landscape-specific adjustments
    final landscapePadding = isLandscape ? (screenWidth * 0.1) : horizontalPadding;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC), // Clean white
              Color(0xFFF1F5F9), // Light gray
              Color(0xFFE2E8F0), // Slightly darker gray
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? landscapePadding : horizontalPadding, 
                vertical: isLandscape ? 10.0 * finalScale : 20.0 * finalScale
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                    SizedBox(height: isSmallScreen ? 20 : 30),
                    // Enhanced Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: backButtonSize,
                        height: backButtonSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(backButtonSize / 2),
                          border: Border.all(color: const Color.fromRGBO(8, 111, 222, 0.977), width: 1),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFE2E8F0),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(backButtonSize / 2),
                            onTap: () => Navigator.pop(context),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: const Color.fromRGBO(8, 111, 222, 0.977),
                              size: isTablet ? 26 : (isSmallScreen ? 18 : 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 30),
                    // Connectivity Status Indicator
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12 * finalScale),
                      decoration: BoxDecoration(
                        color: _isConnected 
                            ? Colors.green.shade50
                            : _hasSyncedData
                                ? Colors.blue.shade50
                                : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8 * finalScale),
                        border: Border.all(
                          color: _isConnected 
                              ? Colors.green.shade300
                              : _hasSyncedData
                                  ? Colors.blue.shade300
                                  : Colors.red.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isConnected 
                                ? Icons.check_circle
                                : _hasSyncedData
                                    ? Icons.cloud_done
                                    : Icons.error,
                            color: _isConnected 
                                ? Colors.green.shade600
                                : _hasSyncedData
                                    ? Colors.blue.shade600
                                    : Colors.red.shade600,
                            size: 20 * finalScale,
                          ),
                          SizedBox(width: 8 * finalScale),
                          Expanded(
                            child: Text(
                              _connectivityStatus,
                              style: TextStyle(
                                fontSize: (isLargeTablet ? 16.0 : (isTablet ? 14.0 : (isVerySmallScreen ? 10.0 : (isSmallScreen ? 12.0 : 13.0)))) * finalScale,
                                color: _isConnected 
                                    ? Colors.green.shade700
                                    : _hasSyncedData
                                        ? Colors.blue.shade700
                                        : Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (_isConnected && !_hasSyncedData)
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const DebugScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Sync After Login',
                                style: TextStyle(
                                  fontSize: (isLargeTablet ? 14.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 9.0 : (isSmallScreen ? 10.0 : 11.0)))) * finalScale,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed: _checkConnectivityStatus,
                            icon: Icon(
                              Icons.refresh,
                              size: 18 * finalScale,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 30),
                    // Clean Login title without neumorphism
                    Column(
                      children: [
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sign in to access your inspector dashboard',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 30 : 40),
                    // Username field
                    _buildNeumorphicTextField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: fieldSpacing),
                    // Password field
                    _buildNeumorphicTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          color: const Color(0xFF718096),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 15 : 20),
                    // Clean Remember me section
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: const Color.fromRGBO(8, 111, 222, 0.977),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Text(
                          'Remember me',
                          style: TextStyle(
                            color: const Color(0xFF1F2937),
                            fontWeight: FontWeight.w500,
                            fontSize: isTablet ? 18 : (isSmallScreen ? 14 : 16),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 30 : 50),
                    // Enhanced Login button
                    Container(
                      width: double.infinity,
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color:  Color.fromRGBO(8, 111, 222, 0.977),
                        borderRadius: BorderRadius.circular(buttonHeight / 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFE2E8F0),
                            offset: Offset(0, 4),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(buttonHeight / 2),
                          onTap: _isLoading ? null : _login,
                          child: Center(
                            child: _isLoading
                                ? SizedBox(
                                    width: isTablet ? 32 : (isSmallScreen ? 24 : 28),
                                    height: isTablet ? 32 : (isSmallScreen ? 24 : 28),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: isTablet ? 22 : (isSmallScreen ? 16 : 20),
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      SizedBox(width: isTablet ? 16 : 12),
                                      Icon(
                                        Icons.login_rounded,
                                        color: Colors.white,
                                        size: isTablet ? 28 : (isSmallScreen ? 20 : 24),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final orientation = MediaQuery.of(context).orientation;
    
    // Enhanced responsive breakpoints
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
    // Dynamic scaling
    // Adjust base height for better tablet scaling
    final double baseHeight = isLandscape ? 600.0 : (isLargeTablet ? 1000.0 : 800.0);
    final double scale = (screenHeight / baseHeight).clamp(0.6, 1.2);
    final double smallScreenScale = isVerySmallScreen ? 0.8 : 1.0;
    final double finalScale = scale * smallScreenScale;
    
    // Enhanced responsive dimensions for text field
    final borderRadius = (isLargeTablet ? 35.0 : (isTablet ? 30.0 : (isVerySmallScreen ? 15.0 : (isSmallScreen ? 20.0 : 25.0)))) * finalScale;
    final fontSize = (isLargeTablet ? 22.0 : (isTablet ? 19.0 : (isVerySmallScreen ? 13.0 : (isSmallScreen ? 15.0 : 17.0)))) * finalScale;
    final labelFontSize = (isLargeTablet ? 22.0 : (isTablet ? 19.0 : (isVerySmallScreen ? 13.0 : (isSmallScreen ? 15.0 : 17.0)))) * finalScale;
    final iconSize = (isLargeTablet ? 28.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0)))) * finalScale;
    final iconContainerSize = (isLargeTablet ? 20.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 10.0 : (isSmallScreen ? 12.0 : 12.0)))) * finalScale;
    final horizontalPadding = (isLargeTablet ? 32.0 : (isTablet ? 28.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 20.0 : 24.0)))) * finalScale;
    final verticalPadding = (isLargeTablet ? 32.0 : (isTablet ? 28.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 20.0 : 24.0)))) * finalScale;
    final iconMargin = (isLargeTablet ? 20.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)))) * finalScale;
    final iconPadding = (isLargeTablet ? 16.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 8.0)))) * finalScale;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            offset: Offset(0, 2),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
          color: const Color(0xFF1F2937),
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: const Color(0xFF6B7280),
            fontSize: labelFontSize,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Container(
            margin: EdgeInsets.all(iconMargin),
            padding: EdgeInsets.all(iconPadding),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(iconContainerSize),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Icon(
              icon,
              color: const Color.fromRGBO(8, 111, 222, 0.977),
              size: iconSize,
            ),
          ),
          suffixIcon: suffixIcon != null ? Container(
            margin: EdgeInsets.all(iconMargin),
            child: suffixIcon,
          ) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          errorStyle: TextStyle(
            color: const Color(0xFFDC2626),
            fontSize: (isVerySmallScreen ? 10.0 : (isSmallScreen ? 12.0 : 14.0)) * finalScale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
