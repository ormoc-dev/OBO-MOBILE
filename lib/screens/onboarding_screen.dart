import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Scan QR Codes',
      description: 'Scan business QR codes to quickly start or resume inspections. This makes it easy to access inspection records in the field.',
      color: const Color.fromRGBO(8, 111, 222, 0.977),
    ),
    OnboardingPage(
      icon: Icons.assessment_rounded,
      title: 'Complete Inspections',
      description: 'Fill out inspection forms with detailed information. Capture photos, videos, and add remarks for each section.',
      color: const Color(0xFF10B981),
    ),
    OnboardingPage(
      icon: Icons.cloud_sync_rounded,
      title: 'Sync Your Data',
      description: 'Sync your data while online to work offline later. Your inspections are stored securely on your device.',
      color: const Color(0xFF8B5CF6),
    ),
    OnboardingPage(
      icon: Icons.dashboard_rounded,
      title: 'Track Progress',
      description: 'View your inspection statistics and progress on the dashboard. See completed, in-progress, and pending inspections.',
      color: const Color(0xFFF59E0B),
    ),
    OnboardingPage(
      icon: Icons.psychology_rounded,
      title: 'Get Help Anytime',
      description: 'Use the debug assistant chatbot (tap the brain icon) for help with setup, troubleshooting, or workflow questions.',
      color: const Color(0xFFEF4444),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  Future<void> _completeOnboarding() async {
    // Only mark as completed if we're coming from the initial app flow
    // If accessed from profile, don't mark as completed (allows re-viewing)
    final cameFromProfile = Navigator.of(context).canPop();
    print('Completing onboarding - cameFromProfile: $cameFromProfile');
    
    if (!cameFromProfile) {
      await OnboardingService.completeOnboarding();
      print('Onboarding marked as completed');
    }
    
    if (mounted) {
      if (cameFromProfile) {
        // If accessed from profile, just pop back
        print('Navigating back to profile');
        Navigator.of(context).pop();
      } else {
        // Navigate to dashboard screen (first time) - use pushReplacement for web compatibility
        print('Navigating to dashboard');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false, // Remove all previous routes
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isLargeTablet = screenSize.width > 900;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFF1F5F9),
              Color(0xFFE2E8F0),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox.shrink(),
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], isTablet, isLargeTablet);
                  },
                ),
              ),

              // Page indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildPageIndicator(index == _currentPage, isTablet),
                ),
              ),

              const SizedBox(height: 20),

              // Navigation buttons
              Padding(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isTablet ? 16 : 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Previous',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _currentPage == _pages.length - 1
                            ? _completeOnboarding
                            : () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 16 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, bool isTablet, bool isLargeTablet) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 40 : 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: isLargeTablet ? 200 : (isTablet ? 160 : 120),
            height: isLargeTablet ? 200 : (isTablet ? 160 : 120),
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: isLargeTablet ? 100 : (isTablet ? 80 : 60),
              color: page.color,
            ),
          ),
          SizedBox(height: isTablet ? 48 : 32),
          // Title
          Text(
            page.title,
            style: TextStyle(
              fontSize: isLargeTablet ? 32 : (isTablet ? 28 : 24),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 24 : 16),
          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: isLargeTablet ? 18 : (isTablet ? 16 : 14),
              color: const Color(0xFF6B7280),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive, bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 6 : 4),
      width: isActive ? (isTablet ? 24 : 20) : (isTablet ? 8 : 6),
      height: isTablet ? 8 : 6,
      decoration: BoxDecoration(
        color: isActive
            ? const Color.fromRGBO(8, 111, 222, 0.977)
            : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

