import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/offline_sync_service.dart';
import '../services/hive_offline_database.dart';
import '../models/user.dart';
import '../models/inspection.dart';
import 'qr_scanner_screen.dart';
import 'profile_screen.dart';
import 'inspection_reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  User? currentUser;
  bool isLoading = true;
  bool _isSyncing = false;
  bool _hasOfflineData = false;
  bool _hasOfflineCredentials = false;
  String _lastSyncTime = 'Never';
  int _currentIndex = 0;
  PageController _pageController = PageController(initialPage: 0);
  
  // Quick Stats data
  int? _todayInspections;
  int? _weeklyCompleted;
  int? _inProgressInspections;
  int? _pendingInspections; // Same as in_progress, but using reports screen terminology
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSyncStatus();
    _loadQuickStats();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh sync status when returning to this screen
    _loadSyncStatus();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getCurrentUser();
      setState(() {
        currentUser = user;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadSyncStatus() async {
    try {
      print('Dashboard: Loading sync status...');
      
      final syncStatus = await OfflineSyncService.getSyncStatus();
      final hasOfflineData = await OfflineSyncService.hasOfflineData();
      final hasCredentials = await OfflineSyncService.hasOfflineCredentials();
      
      print('Dashboard: Sync status loaded:');
      print('  - hasOfflineData: $hasOfflineData');
      print('  - hasCredentials: $hasCredentials');
      print('  - lastSync: ${syncStatus.lastSync}');
      print('  - isSuccess: ${syncStatus.isSuccess}');
      print('  - hasData: ${syncStatus.hasData}');
      
      setState(() {
        _hasOfflineData = hasOfflineData;
        _hasOfflineCredentials = hasCredentials;
        
        if (syncStatus.lastSync != null) {
          _lastSyncTime = syncStatus.lastSync!.toString().substring(0, 19);
        } else {
          _lastSyncTime = 'Never';
        }
      });
    } catch (e) {
      print('Dashboard: Error loading sync status: $e');
      setState(() {
        _hasOfflineData = false;
        _hasOfflineCredentials = false;
        _lastSyncTime = 'Error';
      });
    }
  }

  Future<void> _fetchUserData() async {
    print('Dashboard: Starting sync...');
    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await OfflineSyncService.fetchUserData();
      
      print('Dashboard: Sync completed:');
      print('  - Success: ${result.success}');
      print('  - Message: ${result.message}');
      print('  - Assignments count: ${result.assignmentsCount}');
      
      setState(() {
        _isSyncing = false;
      });

      // Refresh sync status to show updated information
      print('Dashboard: Refreshing sync status after sync...');
      await _loadSyncStatus();
      await _loadQuickStats(); // Refresh quick stats after sync
      
      // Force refresh the UI to show updated status
      if (mounted) {
        setState(() {
          // Trigger a rebuild to show updated sync status
        });
      }

      // Show result dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.success ? 'Sync Successful' : 'Sync Failed'),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      print('Dashboard: Sync error: $e');
      setState(() {
        _isSyncing = false;
      });
      
      // Refresh sync status even after error
      await _loadSyncStatus();
    }
  }

  Future<void> _loadQuickStats() async {
    print('=== DASHBOARD QUICK STATS START ===');
    print('Dashboard: Starting _loadQuickStats...');
    print('Dashboard: Current user: ${currentUser?.id} (${currentUser?.name})');
    setState(() {
      _statsLoading = true;
    });

    try {
      // Ensure Hive is initialized
      await HiveOfflineDatabase.initialize();
      
      // Load inspections from Hive (same as inspection_form_screen.dart)
      final allInspections = HiveOfflineDatabase.getInspections();
      print('Quick Stats: Loaded ${allInspections.length} inspections from Hive');
      
      // Filter inspections by current user (same logic as inspection_reports_screen.dart)
      List<Inspection> inspections;
      if (currentUser?.id == null) {
        print('Dashboard: No current user found, showing all inspections');
        inspections = allInspections;
      } else {
        // Filter inspections by current user
        inspections = allInspections.where((inspection) {
          final matches = inspection.userId == currentUser?.id.toString();
          print('Dashboard: Inspection ${inspection.id}: userId=${inspection.userId}, currentUserId=${currentUser?.id.toString()}, matches=$matches');
          return matches;
        }).toList();
        print('Dashboard: User-specific inspections: ${inspections.length}');
      }
      
      // Debug: Print inspection details
      for (final inspection in inspections) {
        print('  - Inspection: ${inspection.id}');
        print('    Created: ${inspection.createdAt}');
        print('    Updated: ${inspection.updatedAt}');
        print('    Section Status: ${inspection.sectionStatus}');
        print('    User ID: ${inspection.userId}');
        print('    Section Status Values: ${inspection.sectionStatus.values.toList()}');
        print('    Has in_progress: ${inspection.sectionStatus.values.contains('in_progress')}');
        print('    Has passed: ${inspection.sectionStatus.values.contains('passed')}');
        print('    Has not_passed: ${inspection.sectionStatus.values.contains('not_passed')}');
      }
      
      final today = DateTime.now();
      
      // Calculate today's inspections (actual inspection records created today)
      final todayInspections = inspections.where((inspection) {
        final createdDate = inspection.createdAt;
        final isToday = createdDate.year == today.year &&
               createdDate.month == today.month &&
               createdDate.day == today.day;
        if (isToday) {
          print('    Today inspection: ${inspection.id} (${createdDate})');
        } else {
          print('    Not today: ${inspection.id} (${createdDate}) vs today (${today})');
        }
        return isToday;
      }).length;
      
      print('Dashboard: Today inspections count: $todayInspections');
      
      
      // Calculate weekly completed inspections (completed in last 7 days)
      // Using SAME logic as inspection_reports_screen.dart
      final weekAgo = today.subtract(const Duration(days: 7));
      final weeklyCompleted = inspections.where((inspection) {
        // Check if inspection is completed (same logic as reports screen)
        final sectionStatuses = inspection.sectionStatus.values.toList();
        final isCompleted = sectionStatuses.isNotEmpty && 
                           !sectionStatuses.contains('in_progress') &&
                           (sectionStatuses.contains('passed') || sectionStatuses.contains('not_passed'));
        
        print('    Weekly check for ${inspection.id}:');
        print('      Section statuses: $sectionStatuses');
        print('      Is completed: $isCompleted');
        
        if (!isCompleted) return false;
        
        // Check if completed within the last week
        final completedDate = inspection.updatedAt;
        final isWithinWeek = completedDate.isAfter(weekAgo);
        if (isWithinWeek) {
          print('    Weekly completed: ${inspection.id} (${completedDate}) - Status: ${inspection.sectionStatus}');
        } else {
          print('    Completed but not this week: ${inspection.id} (${completedDate}) vs weekAgo (${weekAgo})');
        }
        return isWithinWeek;
      }).length;
      
      print('Dashboard: Weekly completed count: $weeklyCompleted');
      
      // Calculate in-progress inspections (have sections in progress)
      // Using SAME logic as inspection_reports_screen.dart
      final inProgressInspections = inspections.where((inspection) {
        final sectionStatuses = inspection.sectionStatus.values.toList();
        final hasInProgress = sectionStatuses.contains('in_progress');
        if (hasInProgress) {
          print('    In progress: ${inspection.id} (${inspection.sectionStatus})');
        } else {
          print('    Not in progress: ${inspection.id} (${inspection.sectionStatus})');
        }
        return hasInProgress;
      }).length;
      
      print('Dashboard: In progress count: $inProgressInspections');
      
      // Calculate pending inspections (same as in_progress, using reports screen terminology)
      final pendingInspections = inspections.where((inspection) {
        final sectionStatuses = inspection.sectionStatus.values.toList();
        return sectionStatuses.contains('in_progress');
      }).length;
      
      print('Dashboard: Pending inspections count: $pendingInspections');
      
      print('Quick Stats: Today=$todayInspections, Weekly=$weeklyCompleted, InProgress=$inProgressInspections, Pending=$pendingInspections');
      
      setState(() {
        _todayInspections = todayInspections;
        _weeklyCompleted = weeklyCompleted;
        _inProgressInspections = inProgressInspections;
        _pendingInspections = pendingInspections;
        _statsLoading = false;
      });
      
      print('Dashboard: Quick stats loaded successfully');
      print('=== DASHBOARD QUICK STATS END ===');
    } catch (e) {
      print('Error loading quick stats: $e');
      print('=== DASHBOARD QUICK STATS ERROR ===');
      setState(() {
        _todayInspections = 0;
        _weeklyCompleted = 0;
        _inProgressInspections = 0;
        _pendingInspections = 0;
        _statsLoading = false;
      });
    }
  }

  Future<void> _showLogoutConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Confirm Logout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout? You will need to login again to access the app.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF4A5568),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _logout(); // Proceed with logout
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Container(
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
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(8, 111, 222, 0.977)),
            ),
          ),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final orientation = MediaQuery.of(context).orientation;
    
    // Enhanced responsive breakpoints (same as main.dart)
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
    // Dynamic scaling based on screen size and orientation (same as main.dart)
    final double baseHeight = isLandscape ? 600.0 : 800.0;
    final double scale = (screenHeight / baseHeight).clamp(0.6, 1.3);
    final double smallScreenScale = isVerySmallScreen ? 0.8 : 1.0;
    final double finalScale = scale * smallScreenScale;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            // Map page indices to navigation indices
            // Page 0 = Home (nav 0), Page 1 = Report (nav 1), Page 2 = Profile (nav 3)
            _currentIndex = index == 0 ? 0 : (index == 1 ? 1 : 3);
          });
        },
        children: [
          // Page 0: Dashboard Home
          Container(
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
            padding: EdgeInsets.symmetric(
              horizontal: (isLargeTablet ? 40.0 : (isTablet ? 32.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 16.0 : 20.0)))) * finalScale,
              vertical: (isVerySmallScreen ? 12.0 : (isSmallScreen ? 16.0 : 20.0)) * finalScale,
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Neumorphic Header Section
              _buildNeumorphicHeader(context, isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale),
              
              SizedBox(height: (isSmallScreen ? 16.0 : 24.0) * finalScale),
              
              // Quick Stats Overview
              _buildQuickStatsOverview(context, isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale),
              
              SizedBox(height: (isSmallScreen ? 16.0 : 24.0) * finalScale),
              
              // Quick Stats Cards
              _buildQuickStatsSection(context, isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale),
              
              SizedBox(height: (isSmallScreen ? 16.0 : 24.0) * finalScale),
              
                  // Main Dashboard Grid (includes sync status card)
              _buildDashboardGrid(context, isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale),
              
                  SizedBox(height: (isSmallScreen ? 60.0 : 100.0) * finalScale), // Extra space for bottom navbar
            ],
          ),
          ),
        ),
      ),
          
          // Page 1: Reports
          const InspectionReportsScreen(),
          
          // Page 2: Profile
          const ProfileScreen(),
        ],
        ),
      bottomNavigationBar: _buildBottomNavigationBar(context, isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale),
    );
  }

  Widget _buildNeumorphicHeader(BuildContext context, bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale) {
    final avatarSize = (isLargeTablet ? 64.0 : (isTablet ? 56.0 : (isVerySmallScreen ? 40.0 : (isSmallScreen ? 44.0 : 52.0)))) * finalScale;
    final statusIndicatorSize = (isLargeTablet ? 16.0 : (isTablet ? 14.0 : (isVerySmallScreen ? 10.0 : (isSmallScreen ? 11.0 : 12.0)))) * finalScale;
    
    return Container(
      padding: EdgeInsets.all((isLargeTablet ? 24.0 : (isTablet ? 20.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0)))) * finalScale),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8FAFC),
          ],
        ),
        borderRadius: BorderRadius.circular((isLargeTablet ? 20.0 : (isTablet ? 18.0 : (isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 18.0)))) * finalScale),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // User Avatar with Status Indicator
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromRGBO(8, 111, 222, 0.977),
                      Color.fromRGBO(22, 127, 239, 0.976),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(8, 111, 222, 0.25),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    (currentUser?.name != null && currentUser!.name.isNotEmpty)
                        ? currentUser!.name.substring(0, 1).toUpperCase()
                        : 'I',
                    style: TextStyle(
                      fontSize: (isLargeTablet ? 28.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 22.0)))) * finalScale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // Status Indicator
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: statusIndicatorSize,
                  height: statusIndicatorSize,
                  decoration: BoxDecoration(
                    color: _getStatusColor(currentUser?.status),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(currentUser?.status).withOpacity(0.4),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: (isLargeTablet ? 20.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0)))) * finalScale),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Good ${_getGreeting()}',
                        style: TextStyle(
                          fontSize: (isLargeTablet ? 16.0 : (isTablet ? 14.0 : (isVerySmallScreen ? 11.0 : (isSmallScreen ? 12.0 : 13.0)))) * finalScale,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: (isVerySmallScreen ? 4.0 : (isSmallScreen ? 5.0 : 6.0)) * finalScale),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        currentUser?.name ?? 'Inspector',
                        style: TextStyle(
                          fontSize: (isLargeTablet ? 24.0 : (isTablet ? 22.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0)))) * finalScale,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                          letterSpacing: 0.2,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: (isLargeTablet ? 16.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)))) * finalScale),
          // Right Side - Role and Status Badges
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Inspector Badge (Role)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: (isLargeTablet ? 14.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 9.0 : 10.0)))) * finalScale,
                  vertical: (isLargeTablet ? 8.0 : (isTablet ? 7.0 : (isVerySmallScreen ? 5.0 : (isSmallScreen ? 5.5 : 6.0)))) * finalScale,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(8, 111, 222, 0.1),
                  borderRadius: BorderRadius.circular((isLargeTablet ? 10.0 : (isTablet ? 9.0 : (isVerySmallScreen ? 7.0 : (isSmallScreen ? 8.0 : 9.0)))) * finalScale),
                  border: Border.all(
                    color: const Color.fromRGBO(8, 111, 222, 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(8, 111, 222, 0.1),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.badge_rounded,
                      size: (isLargeTablet ? 16.0 : (isTablet ? 14.0 : (isVerySmallScreen ? 11.0 : (isSmallScreen ? 12.0 : 13.0)))) * finalScale,
                      color: const Color.fromRGBO(8, 111, 222, 0.977),
                    ),
                    SizedBox(width: (isVerySmallScreen ? 4.0 : (isSmallScreen ? 5.0 : 6.0)) * finalScale),
                    Text(
                      currentUser?.role ?? 'Inspector',
                      style: TextStyle(
                        fontSize: (isLargeTablet ? 14.0 : (isTablet ? 13.0 : (isVerySmallScreen ? 10.0 : (isSmallScreen ? 11.0 : 12.0)))) * finalScale,
                        fontWeight: FontWeight.w600,
                        color: const Color.fromRGBO(8, 111, 222, 0.977),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: (isLargeTablet ? 10.0 : (isTablet ? 8.0 : (isVerySmallScreen ? 6.0 : (isSmallScreen ? 7.0 : 8.0)))) * finalScale),
              // Active Badge (Status)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: (isLargeTablet ? 14.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 9.0 : 10.0)))) * finalScale,
                  vertical: (isLargeTablet ? 8.0 : (isTablet ? 7.0 : (isVerySmallScreen ? 5.0 : (isSmallScreen ? 5.5 : 6.0)))) * finalScale,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(currentUser?.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular((isLargeTablet ? 10.0 : (isTablet ? 9.0 : (isVerySmallScreen ? 7.0 : (isSmallScreen ? 8.0 : 9.0)))) * finalScale),
                  border: Border.all(
                    color: _getStatusColor(currentUser?.status).withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusColor(currentUser?.status).withOpacity(0.1),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: (isLargeTablet ? 10.0 : (isTablet ? 9.0 : (isVerySmallScreen ? 7.0 : (isSmallScreen ? 7.5 : 8.0)))) * finalScale,
                      height: (isLargeTablet ? 10.0 : (isTablet ? 9.0 : (isVerySmallScreen ? 7.0 : (isSmallScreen ? 7.5 : 8.0)))) * finalScale,
                      decoration: BoxDecoration(
                        color: _getStatusColor(currentUser?.status),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(currentUser?.status).withOpacity(0.4),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: (isVerySmallScreen ? 4.0 : (isSmallScreen ? 5.0 : 6.0)) * finalScale),
                    Text(
                      currentUser?.status?.toUpperCase() ?? 'ACTIVE',
                      style: TextStyle(
                        fontSize: (isLargeTablet ? 13.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 10.0 : (isSmallScreen ? 11.0 : 12.0)))) * finalScale,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(currentUser?.status),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection(BuildContext context, bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            'Status',
            currentUser?.status ?? 'Active',
            Icons.verified_user_rounded,
            _getStatusColor(currentUser?.status),
            isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale,
          ),
        ),
        SizedBox(width: (isLargeTablet ? 20.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)))) * finalScale),
        Expanded(
          child: _buildQuickStatCard(
            'Role',
            currentUser?.role ?? 'Inspector',
            Icons.badge_rounded,
            const Color(0xFF10B981),
            isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color, bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale) {
    return Container(
      padding: EdgeInsets.all((isLargeTablet ? 24.0 : (isTablet ? 20.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0)))) * finalScale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular((isLargeTablet ? 18.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 10.0 : (isSmallScreen ? 12.0 : 14.0)))) * finalScale),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all((isVerySmallScreen ? 4.0 : (isSmallScreen ? 6.0 : 8.0)) * finalScale),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular((isVerySmallScreen ? 4.0 : (isSmallScreen ? 6.0 : 8.0)) * finalScale),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Icon(
              icon,
              color: color,
              size: (isLargeTablet ? 28.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0)))) * finalScale,
            ),
          ),
          SizedBox(height: (isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : (isTablet ? 12.0 : 8.0))) * finalScale),
          Text(
            title,
            style: TextStyle(
              fontSize: (isLargeTablet ? 16.0 : (isTablet ? 14.0 : (isVerySmallScreen ? 10.0 : (isSmallScreen ? 11.0 : 12.0)))) * finalScale,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: (isVerySmallScreen ? 2.0 : 4.0) * finalScale),
          Text(
            value,
            style: TextStyle(
              fontSize: (isLargeTablet ? 20.0 : (isTablet ? 18.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0)))) * finalScale,
              color: const Color(0xFF1F2937),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSyncStatusCard(BuildContext context, bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale) {
    return Container(
      padding: EdgeInsets.all((isLargeTablet ? 28.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0)))) * finalScale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular((isLargeTablet ? 24.0 : (isTablet ? 20.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0)))) * finalScale),
        border: Border.all(
          color: const Color.fromRGBO(8, 111, 222, 0.977),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(8, 111, 222, 0.977).withValues(alpha: 0.15),
            offset: const Offset(0, 6),
            blurRadius: 20,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color.fromRGBO(8, 111, 222, 0.977).withValues(alpha: 0.1),
            offset: const Offset(0, 3),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color.fromRGBO(8, 111, 222, 0.977),
                      const Color.fromRGBO(8, 111, 222, 0.977).withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(8, 111, 222, 0.977).withValues(alpha: 0.3),
                      offset: const Offset(0, 3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  _hasOfflineData ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: isTablet ? 28 : 24,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Sync Status',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: isTablet ? 4 : 2),
                    Text(
                      _hasOfflineData 
                        ? 'Your data is synced and available offline'
                        : 'Sync your data to work offline',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: isTablet ? 20 : 16),
          
          // Sync Button Section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(8, 111, 222, 0.977).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color.fromRGBO(8, 111, 222, 0.977).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isSyncing ? null : _fetchUserData,
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  child: Row(
                    children: [
                      // Sync Icon
                      Container(
                        width: isTablet ? 50 : 45,
                        height: isTablet ? 50 : 45,
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(8, 111, 222, 0.977),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _isSyncing
                              ? SizedBox(
                                  width: isTablet ? 24 : 20,
                                  height: isTablet ? 24 : 20,
                                  child: const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 3,
                                  ),
                                )
                              : Icon(
                                  Icons.sync_rounded,
                                  size: isTablet ? 24 : 20,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      
                      SizedBox(width: isTablet ? 16 : 12),
                      
                      // Sync Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sync All Data',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            SizedBox(height: isTablet ? 2 : 1),
                            Text(
                              _isSyncing ? 'Synchronizing all data...' : 'Sync all of your data',
                              style: TextStyle(
                                fontSize: isTablet ? 12 : 10,
                                color: const Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Action Indicator
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 12 : 10,
                          vertical: isTablet ? 6 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(8, 111, 222, 0.977).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color.fromRGBO(8, 111, 222, 0.977).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSyncing ? Icons.hourglass_empty_rounded : Icons.touch_app_rounded,
                              size: isTablet ? 14 : 12,
                              color: const Color.fromRGBO(8, 111, 222, 0.977),
                            ),
                            SizedBox(width: isTablet ? 4 : 2),
                            Text(
                              _isSyncing ? 'Wait...' : 'Tap',
                              style: TextStyle(
                                fontSize: isTablet ? 10 : 8,
                                fontWeight: FontWeight.w600,
                                color: const Color.fromRGBO(8, 111, 222, 0.977),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          SizedBox(height: isTablet ? 20 : 16),
          
          // Status Items Section
          if (isTablet) ...[
            // Tablet layout - horizontal
            Row(
              children: [
                Expanded(
                  child: _buildSyncStatusItem(
                    'Offline Data',
                    _hasOfflineData ? 'Available' : 'Not Available',
                    _hasOfflineData ? Colors.green : Colors.red,
                    isTablet,
                  ),
                ),
                SizedBox(width: isTablet ? 24 : 16),
                Expanded(
                  child: _buildSyncStatusItem(
                    'Offline Login',
                    _hasOfflineCredentials ? 'Available' : 'Not Available',
                    _hasOfflineCredentials ? Colors.green : Colors.red,
                    isTablet,
                  ),
                ),
                SizedBox(width: isTablet ? 24 : 16),
                Expanded(
                  child: _buildSyncStatusItem(
                    'Last Sync',
                    _lastSyncTime,
                    _lastSyncTime == 'Never' ? Colors.grey : const Color.fromRGBO(8, 111, 222, 0.977),
                    isTablet,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Mobile layout - vertical
            _buildSyncStatusItem(
              'Offline Data',
              _hasOfflineData ? 'Available' : 'Not Available',
              _hasOfflineData ? Colors.green : Colors.red,
              isTablet,
            ),
            const SizedBox(height: 12),
            _buildSyncStatusItem(
              'Offline Login',
              _hasOfflineCredentials ? 'Available' : 'Not Available',
              _hasOfflineCredentials ? Colors.green : Colors.red,
              isTablet,
            ),
            const SizedBox(height: 12),
            _buildSyncStatusItem(
              'Last Sync',
              _lastSyncTime,
              _lastSyncTime == 'Never' ? Colors.grey : const Color.fromRGBO(8, 111, 222, 0.977),
              isTablet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncStatusItem(String label, String value, Color color, bool isTablet) {
    return Row(
      children: [
        Container(
          width: isTablet ? 12 : 10,
          height: isTablet ? 12 : 10,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Center(
            child: Container(
              width: isTablet ? 6 : 5,
              height: isTablet ? 6 : 5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        SizedBox(width: isTablet ? 12 : 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardGrid(BuildContext context, bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       
        SizedBox(height: (isLargeTablet ? 24.0 : (isTablet ? 20.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0)))) * finalScale),
        
        // Sync Status Card with integrated sync button
        _buildSyncStatusCard(context, isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }



  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return const Color(0xFF059669);
      case 'inactive':
        return const Color(0xFFDC2626);
      case 'pending':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF6B7280);
    }
  }


  Widget _buildBottomNavigationBar(BuildContext context, bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale) {
    final navHeight = (isLargeTablet ? 85.0 : (isTablet ? 80.0 : (isVerySmallScreen ? 72.0 : (isSmallScreen ? 75.0 : 78.0)))) * finalScale;
    final qrButtonSize = (isLargeTablet ? 68.0 : (isTablet ? 64.0 : (isVerySmallScreen ? 52.0 : (isSmallScreen ? 56.0 : 60.0)))) * finalScale;
    
    return Container(
      height: navHeight + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, -2),
            blurRadius: 24,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, -1),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            top: (isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 10.0)) * finalScale,
            bottom: (isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 10.0)) * finalScale,
            left: (isLargeTablet ? 16.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)))) * finalScale,
            right: (isLargeTablet ? 16.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)))) * finalScale,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Main navigation items row - with proper spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side - Home, Report
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: qrButtonSize * 0.35),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Home
                          Expanded(
                            child: _buildNavItem(
                              icon: Icons.home_rounded,
                              label: 'Home',
                              isSelected: _currentIndex == 0,
                              onTap: () => _onNavItemTapped(0),
                              isTablet: isTablet, 
                              isLargeTablet: isLargeTablet, 
                              isSmallScreen: isSmallScreen, 
                              isVerySmallScreen: isVerySmallScreen, 
                              finalScale: finalScale,
                            ),
                          ),
                          
                          // Report
                          Expanded(
                            child: _buildNavItem(
                              icon: Icons.assessment_rounded,
                              label: 'Report',
                              isSelected: _currentIndex == 1,
                              onTap: () => _onNavItemTapped(1),
                              isTablet: isTablet, 
                              isLargeTablet: isLargeTablet, 
                              isSmallScreen: isSmallScreen, 
                              isVerySmallScreen: isVerySmallScreen, 
                              finalScale: finalScale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Right side - Profile, Logout (with spacing from QR button)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: qrButtonSize * 0.35),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Profile
                          Expanded(
                            child: _buildNavItem(
                              icon: Icons.person_rounded,
                              label: 'Profile',
                              isSelected: _currentIndex == 3,
                              onTap: () => _onNavItemTapped(3),
                              isTablet: isTablet, 
                              isLargeTablet: isLargeTablet, 
                              isSmallScreen: isSmallScreen, 
                              isVerySmallScreen: isVerySmallScreen, 
                              finalScale: finalScale,
                            ),
                          ),
                          
                          // Logout
                          Expanded(
                            child: _buildLogoutNavItem(
                              isTablet: isTablet, 
                              isLargeTablet: isLargeTablet, 
                              isSmallScreen: isSmallScreen, 
                              isVerySmallScreen: isVerySmallScreen, 
                              finalScale: finalScale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // QR Code Button - Positioned absolutely in center, elevated
              Positioned(
                top: -qrButtonSize / 3,
                child: IgnorePointer(
                  ignoring: false,
                  child: _buildQRCodeButton(isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale, qrButtonSize),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isTablet,
    required bool isLargeTablet,
    required bool isSmallScreen,
    required bool isVerySmallScreen,
    required double finalScale,
  }) {
    final iconSize = (isLargeTablet ? 24.0 : (isTablet ? 22.0 : (isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 22.0)))) * finalScale;
    final fontSize = (isLargeTablet ? 11.0 : (isTablet ? 10.0 : (isVerySmallScreen ? 7.5 : (isSmallScreen ? 8.5 : 9.5)))) * finalScale;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12 * finalScale),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: (isVerySmallScreen ? 2.0 : (isSmallScreen ? 4.0 : 6.0)) * finalScale,
            vertical: (isVerySmallScreen ? 4.0 : (isSmallScreen ? 6.0 : 8.0)) * finalScale,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected 
                  ? const Color.fromRGBO(8, 111, 222, 0.977)
                  : const Color(0xFF6B7280),
                size: iconSize,
              ),
              SizedBox(height: (isVerySmallScreen ? 1.0 : (isSmallScreen ? 2.0 : 3.0)) * finalScale),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  color: isSelected 
                    ? const Color.fromRGBO(8, 111, 222, 0.977)
                    : const Color(0xFF6B7280),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.1,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRCodeButton(bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale, double buttonSize) {
    final iconSize = (isLargeTablet ? 28.0 : (isTablet ? 26.0 : (isVerySmallScreen ? 22.0 : (isSmallScreen ? 24.0 : 26.0)))) * finalScale;
    final fontSize = (isLargeTablet ? 10.0 : (isTablet ? 9.0 : (isVerySmallScreen ? 7.0 : (isSmallScreen ? 8.0 : 9.0)))) * finalScale;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNavItemTapped(2),
        borderRadius: BorderRadius.circular(buttonSize / 2),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromRGBO(8, 111, 222, 0.977),
                Color.fromRGBO(22, 127, 239, 0.976),
              ],
            ),
            borderRadius: BorderRadius.circular(buttonSize / 2),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(8, 111, 222, 0.35),
                offset: const Offset(0, 6),
                blurRadius: 16,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: const Color.fromRGBO(8, 111, 222, 0.2),
                offset: const Offset(0, 2),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: iconSize,
              ),
              SizedBox(height: (isVerySmallScreen ? 1.0 : (isSmallScreen ? 1.0 : 2.0)) * finalScale),
              Text(
                'QR Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutNavItem({
    required bool isTablet,
    required bool isLargeTablet,
    required bool isSmallScreen,
    required bool isVerySmallScreen,
    required double finalScale,
  }) {
    final iconSize = (isLargeTablet ? 24.0 : (isTablet ? 22.0 : (isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 22.0)))) * finalScale;
    final fontSize = (isLargeTablet ? 11.0 : (isTablet ? 10.0 : (isVerySmallScreen ? 7.5 : (isSmallScreen ? 8.5 : 9.5)))) * finalScale;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showLogoutConfirmation,
        borderRadius: BorderRadius.circular(12 * finalScale),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: (isVerySmallScreen ? 2.0 : (isSmallScreen ? 4.0 : 6.0)) * finalScale,
            vertical: (isVerySmallScreen ? 4.0 : (isSmallScreen ? 6.0 : 8.0)) * finalScale,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12 * finalScale),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                color: Colors.red.shade700,
                size: iconSize,
              ),
              SizedBox(height: (isVerySmallScreen ? 1.0 : (isSmallScreen ? 2.0 : 3.0)) * finalScale),
              Text(
                'Logout',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onNavItemTapped(int index) {
    // Map navigation indices to page indices
    int pageIndex;
    switch (index) {
      case 0: // Home
        pageIndex = 0;
        break;
      case 1: // Report
        pageIndex = 1;
        break;
      case 2: // QR Scanner - special case
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
        return;
      case 3: // Profile
        pageIndex = 2;
        break;
      default:
        pageIndex = 0;
    }
    
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildQuickStatsOverview(BuildContext context, bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((isLargeTablet ? 28.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0)))) * finalScale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular((isLargeTablet ? 20.0 : (isTablet ? 18.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0)))) * finalScale),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: isMobile ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isMobile ? 0.03 : 0.05),
            offset: const Offset(0, 2),
            blurRadius: isMobile ? 6 : 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: const Color.fromRGBO(8, 111, 222, 0.977),
                size: (isLargeTablet ? 26.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 22.0)))) * finalScale,
              ),
              SizedBox(width: (isLargeTablet ? 10.0 : (isTablet ? 8.0 : (isVerySmallScreen ? 6.0 : (isSmallScreen ? 7.0 : 8.0)))) * finalScale),
              Expanded(
                child: Text(
                  'Quick Stats Overview',
                  style: TextStyle(
                    fontSize: (isLargeTablet ? 22.0 : (isTablet ? 20.0 : (isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 18.0)))) * finalScale,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                    letterSpacing: isMobile ? 0.2 : 0.3,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: (isLargeTablet ? 20.0 : (isTablet ? 18.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0)))) * finalScale),
          
          // Stats Grid
          if (_statsLoading)
            _buildStatsLoading(context, isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale)
          else
            _buildStatsGrid(context, isTablet, isLargeTablet, isSmallScreen, isVerySmallScreen, finalScale),
        ],
      ),
    );
  }

  Widget _buildStatsLoading(BuildContext context, bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // For mobile, use 2x2 grid loading
    if (isMobile && !isTablet) {
      return Column(
        children: [
          Row(
            children: List.generate(2, (index) => 
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: (isVerySmallScreen ? 3.0 : (isSmallScreen ? 3.5 : 4.0)) * finalScale,
                  ),
                  height: (isVerySmallScreen ? 60.0 : (isSmallScreen ? 65.0 : 70.0)) * finalScale,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular((isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)) * finalScale),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: (isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 22.0)) * finalScale,
                      height: (isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 22.0)) * finalScale,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromRGBO(8, 111, 222, 0.977),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: (isVerySmallScreen ? 6.0 : (isSmallScreen ? 7.0 : 8.0)) * finalScale),
          Row(
            children: List.generate(2, (index) => 
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: (isVerySmallScreen ? 3.0 : (isSmallScreen ? 3.5 : 4.0)) * finalScale,
                  ),
                  height: (isVerySmallScreen ? 60.0 : (isSmallScreen ? 65.0 : 70.0)) * finalScale,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular((isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)) * finalScale),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: (isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 22.0)) * finalScale,
                      height: (isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 22.0)) * finalScale,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromRGBO(8, 111, 222, 0.977),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // For tablets, use horizontal layout
    return Container(
      height: (isLargeTablet ? 85.0 : (isTablet ? 80.0 : 70.0)) * finalScale,
      child: Row(
        children: List.generate(4, (index) => 
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: (isLargeTablet ? 4.0 : (isTablet ? 3.0 : 2.0)) * finalScale),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular((isLargeTablet ? 14.0 : (isTablet ? 12.0 : 10.0)) * finalScale),
              ),
              child: Center(
                child: SizedBox(
                  width: (isLargeTablet ? 26.0 : (isTablet ? 24.0 : 20.0)) * finalScale,
                  height: (isLargeTablet ? 26.0 : (isTablet ? 24.0 : 20.0)) * finalScale,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromRGBO(8, 111, 222, 0.977),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // For mobile phones (not tablets), always use 2x2 grid for better readability
    if (isMobile && !isTablet) {
      return Column(
        children: [
          // First row - 2 items
          Row(
            children: [
              Expanded(
                child: _buildOverviewStatCard(
                  'Today\'s\nInspections',
                  (_todayInspections ?? 0).toString(),
                  Icons.calendar_today_outlined,
                  const Color.fromRGBO(8, 111, 222, 0.977),
                  isTablet,
                  isLargeTablet,
                  isSmallScreen,
                  isVerySmallScreen,
                  finalScale,
                ),
              ),
              SizedBox(width: (isVerySmallScreen ? 6.0 : (isSmallScreen ? 7.0 : 8.0)) * finalScale),
              Expanded(
                child: _buildOverviewStatCard(
                  'Pending\nInspections',
                  (_pendingInspections ?? 0).toString(),
                  Icons.hourglass_empty_outlined,
                  const Color(0xFF8B5CF6),
                  isTablet,
                  isLargeTablet,
                  isSmallScreen,
                  isVerySmallScreen,
                  finalScale,
                ),
              ),
            ],
          ),
          SizedBox(height: (isVerySmallScreen ? 6.0 : (isSmallScreen ? 7.0 : 8.0)) * finalScale),
          // Second row - 2 items
          Row(
            children: [
              Expanded(
                child: _buildOverviewStatCard(
                  'Completed\nThis Week',
                  (_weeklyCompleted ?? 0).toString(),
                  Icons.check_circle_outline,
                  const Color(0xFF10B981),
                  isTablet,
                  isLargeTablet,
                  isSmallScreen,
                  isVerySmallScreen,
                  finalScale,
                ),
              ),
              SizedBox(width: (isVerySmallScreen ? 6.0 : (isSmallScreen ? 7.0 : 8.0)) * finalScale),
              Expanded(
                child: _buildOverviewStatCard(
                  'In Progress',
                  (_inProgressInspections ?? 0).toString(),
                  Icons.timeline_outlined,
                  const Color(0xFF06B6D4),
                  isTablet,
                  isLargeTablet,
                  isSmallScreen,
                  isVerySmallScreen,
                  finalScale,
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    // For tablets and larger screens, use horizontal layout
    return Row(
      children: [
        // Today's Inspections
        Expanded(
          child: _buildOverviewStatCard(
            'Today\'s\nInspections',
            (_todayInspections ?? 0).toString(),
            Icons.calendar_today_outlined,
            const Color.fromRGBO(8, 111, 222, 0.977),
            isTablet,
            isLargeTablet,
            isSmallScreen,
            isVerySmallScreen,
            finalScale,
          ),
        ),
        SizedBox(width: (isLargeTablet ? 8.0 : (isTablet ? 6.0 : 4.0)) * finalScale),
        
        // Pending Inspections
        Expanded(
          child: _buildOverviewStatCard(
            'Pending\nInspections',
            (_pendingInspections ?? 0).toString(),
            Icons.hourglass_empty_outlined,
            const Color(0xFF8B5CF6),
            isTablet,
            isLargeTablet,
            isSmallScreen,
            isVerySmallScreen,
            finalScale,
          ),
        ),
        SizedBox(width: (isLargeTablet ? 8.0 : (isTablet ? 6.0 : 4.0)) * finalScale),
        
        // Weekly Completed
        Expanded(
          child: _buildOverviewStatCard(
            'Completed\nThis Week',
            (_weeklyCompleted ?? 0).toString(),
            Icons.check_circle_outline,
            const Color(0xFF10B981),
            isTablet,
            isLargeTablet,
            isSmallScreen,
            isVerySmallScreen,
            finalScale,
          ),
        ),
        SizedBox(width: (isLargeTablet ? 8.0 : (isTablet ? 6.0 : 4.0)) * finalScale),
        
        // In Progress
        Expanded(
          child: _buildOverviewStatCard(
            'In Progress',
            (_inProgressInspections ?? 0).toString(),
            Icons.timeline_outlined,
            const Color(0xFF06B6D4),
            isTablet,
            isLargeTablet,
            isSmallScreen,
            isVerySmallScreen,
            finalScale,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewStatCard(String title, String value, IconData icon, Color color, bool isTablet, bool isLargeTablet, bool isSmallScreen, bool isVerySmallScreen, double finalScale) {
    return Container(
      padding: EdgeInsets.all((isLargeTablet ? 18.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)))) * finalScale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular((isLargeTablet ? 16.0 : (isTablet ? 14.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0)))) * finalScale),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: isTablet ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: (isLargeTablet ? 26.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0)))) * finalScale,
          ),
          SizedBox(height: (isLargeTablet ? 10.0 : (isTablet ? 8.0 : (isVerySmallScreen ? 4.0 : (isSmallScreen ? 5.0 : 6.0)))) * finalScale),
          Text(
            value,
            style: TextStyle(
              fontSize: (isLargeTablet ? 22.0 : (isTablet ? 20.0 : (isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 18.0)))) * finalScale,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.1,
            ),
          ),
          SizedBox(height: (isLargeTablet ? 6.0 : (isTablet ? 5.0 : (isVerySmallScreen ? 2.0 : (isSmallScreen ? 3.0 : 4.0)))) * finalScale),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: (isLargeTablet ? 13.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 9.0 : 10.0)))) * finalScale,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

}