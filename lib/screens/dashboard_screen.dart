import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/offline_sync_service.dart';
import '../services/hive_offline_database.dart';
import '../models/user.dart';
import 'assignments_screen.dart';
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
  int _todayInspections = 0;
  int _pendingAssignments = 0;
  int _weeklyCompleted = 0;
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
    setState(() {
      _statsLoading = true;
    });

    try {
      // Ensure Hive is initialized
      await HiveOfflineDatabase.initialize();
      
      // Load assignments from Hive
      final assignments = HiveOfflineDatabase.getAssignments();
      print('Quick Stats: Loaded ${assignments.length} assignments from Hive');
      
      // Calculate today's inspections (assignments due today)
      final today = DateTime.now();
      final todayInspections = assignments.where((assignment) {
        final assignedDate = DateTime.tryParse(assignment.assignedAt) ?? DateTime.now();
        return assignedDate.year == today.year &&
               assignedDate.month == today.month &&
               assignedDate.day == today.day;
      }).length;
      
      // Calculate pending assignments (assigned status)
      final pendingAssignments = assignments.where((assignment) {
        return assignment.statusDisplayName.toLowerCase() == 'assigned';
      }).length;
      
      // Calculate weekly completed (completed in last 7 days)
      final weekAgo = today.subtract(const Duration(days: 7));
      final weeklyCompleted = assignments.where((assignment) {
        if (assignment.statusDisplayName.toLowerCase() != 'completed') return false;
        final completedDate = DateTime.tryParse(assignment.assignedAt) ?? DateTime.now();
        return completedDate.isAfter(weekAgo);
      }).length;
      
      print('Quick Stats: Today=$todayInspections, Pending=$pendingAssignments, Weekly=$weeklyCompleted');
      
      setState(() {
        _todayInspections = todayInspections;
        _pendingAssignments = pendingAssignments;
        _weeklyCompleted = weeklyCompleted;
        _statsLoading = false;
      });
    } catch (e) {
      print('Error loading quick stats: $e');
      setState(() {
        _todayInspections = 0;
        _pendingAssignments = 0;
        _weeklyCompleted = 0;
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
            'Are you sure you want to logout? You will need to login again to access your assignments.',
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
    
    // Enhanced responsive breakpoints
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
    // Dynamic scaling based on screen size and orientation
    final double baseHeight = isLandscape ? 600.0 : 800.0;
    final double scale = (screenHeight / baseHeight).clamp(0.6, 1.3);
    final double smallScreenScale = isVerySmallScreen ? 0.8 : 1.0;
    final double finalScale = scale * smallScreenScale;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
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
              horizontal: (isLargeTablet ? 40.0 : (isTablet ? 32.0 : (isVerySmallScreen ? 12.0 : 16.0))) * finalScale,
              vertical: (isVerySmallScreen ? 12.0 : 16.0) * finalScale,
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Neumorphic Header Section
              _buildNeumorphicHeader(context, isTablet),
              
              const SizedBox(height: 24),
              
              // Quick Stats Overview
              _buildQuickStatsOverview(context, isTablet),
              
              const SizedBox(height: 24),
              
              // Quick Stats Cards
              _buildQuickStatsSection(context, isTablet),
              
              const SizedBox(height: 24),
              
                  // Main Dashboard Grid (includes sync status card)
              _buildDashboardGrid(context, isTablet),
              
                  const SizedBox(height: 100), // Extra space for bottom navbar
            ],
          ),
          ),
        ),
      ),
          
          // Page 1: Assignments
          const AssignmentsScreen(),
          
          // Page 2: Reports
          const InspectionReportsScreen(),
          
          // Page 3: Profile
          const ProfileScreen(),
        ],
        ),
      bottomNavigationBar: _buildBottomNavigationBar(context, isTablet),
    );
  }

  Widget _buildNeumorphicHeader(BuildContext context, bool isTablet) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final orientation = MediaQuery.of(context).orientation;
    
    // Enhanced responsive breakpoints
    final isLargeTablet = screenWidth > 900;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
    // Dynamic scaling
    final double baseHeight = isLandscape ? 600.0 : 800.0;
    final double scale = (screenHeight / baseHeight).clamp(0.6, 1.3);
    final double smallScreenScale = isVerySmallScreen ? 0.8 : 1.0;
    final double finalScale = scale * smallScreenScale;
    
    return Container(
      padding: EdgeInsets.all((isLargeTablet ? 28.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 16.0 : 20.0))) * finalScale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * finalScale),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            offset: Offset(0, 4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_getGreeting()}',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentUser?.name ?? 'Inspector',
                  style: TextStyle(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
              
              ],
            ),
          ),
          Container(
            width: isTablet ? 60 : 50,
            height: isTablet ? 60 : 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isTablet ? 30 : 25),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(isTablet ? 30 : 25),
                onTap: _showLogoutConfirmation,
                child: Icon(
                  Icons.logout_rounded,
                  color: const Color.fromRGBO(8, 111, 222, 0.977),
                  size: isTablet ? 28 : 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection(BuildContext context, bool isTablet) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            'Status',
            currentUser?.status ?? 'Active',
            Icons.verified_user_rounded,
            _getStatusColor(currentUser?.status),
            isTablet,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: _buildQuickStatCard(
            'Role',
            currentUser?.role ?? 'Inspector',
            Icons.badge_rounded,
            const Color(0xFF10B981),
            isTablet,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Icon(
              icon,
              color: color,
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: const Color(0xFF1F2937),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSyncStatusCard(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                              'Sync My Data',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            SizedBox(height: isTablet ? 2 : 1),
                            Text(
                              _isSyncing ? 'Synchronizing your data...' : 'Keep your data up to date',
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

  Widget _buildDashboardGrid(BuildContext context, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       
        SizedBox(height: isTablet ? 20 : 16),
        
        // Sync Status Card with integrated sync button
        _buildSyncStatusCard(context, isTablet),
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


  Widget _buildBottomNavigationBar(BuildContext context, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, -4),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 16,
            vertical: isTablet ? 16 : 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
              // Home/Dashboard
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: _currentIndex == 0,
                onTap: () => _onNavItemTapped(0),
                isTablet: isTablet,
              ),
              
              // Assignments
              _buildNavItem(
                icon: Icons.assignment_rounded,
                label: 'Assignments',
                isSelected: _currentIndex == 1,
                onTap: () => _onNavItemTapped(1),
                isTablet: isTablet,
              ),
              
              // QR Scanner - Center Button
              _buildQRScannerButton(isTablet),
              
              // Reports
              _buildNavItem(
                icon: Icons.assessment_rounded,
                label: 'Reports',
                isSelected: _currentIndex == 3,
                onTap: () => _onNavItemTapped(3),
                isTablet: isTablet,
              ),
              
              // Profile
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isSelected: _currentIndex == 4,
                onTap: () => _onNavItemTapped(4),
                isTablet: isTablet,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
                padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 12 : 8,
                ),
        decoration: BoxDecoration(
          color: isSelected ? const Color.fromRGBO(8, 111, 222, 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
                children: [
            Icon(
              icon,
              color: isSelected 
                ? const Color.fromRGBO(8, 111, 222, 0.977)
                : const Color(0xFF6B7280),
              size: isTablet ? 28 : 24,
            ),
            SizedBox(height: isTablet ? 6 : 4),
                  Text(
              label,
                    style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                color: isSelected 
                  ? const Color.fromRGBO(8, 111, 222, 0.977)
                  : const Color(0xFF6B7280),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildQRScannerButton(bool isTablet) {
    return GestureDetector(
      onTap: () => _onNavItemTapped(2),
      child: Container(
        width: isTablet ? 80 : 70,
        height: isTablet ? 80 : 70,
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(8, 111, 222, 0.977),
              Color.fromRGBO(22, 127, 239, 0.976),
            ],
          ),
          borderRadius: BorderRadius.circular(isTablet ? 40 : 35),
          boxShadow: [
          BoxShadow(
              color: const Color.fromRGBO(8, 111, 222, 0.3),
              offset: const Offset(0, 4),
              blurRadius: 12,
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
                          size: isTablet ? 32 : 28,
                        ),
            SizedBox(height: isTablet ? 4 : 2),
                Text(
              'Scan',
                  style: TextStyle(
                color: Colors.white,
                      fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
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
      case 1: // Assignments
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
      case 3: // Reports
        pageIndex = 2;
        break;
      case 4: // Profile
        pageIndex = 3;
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

  Widget _buildQuickStatsOverview(BuildContext context, bool isTablet) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final orientation = MediaQuery.of(context).orientation;
    
    // Enhanced responsive breakpoints
    final isLargeTablet = screenWidth > 900;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    final isSmallPhone = screenWidth < 400;
    
    // Dynamic scaling
    final double baseHeight = isLandscape ? 600.0 : 800.0;
    final double scale = (screenHeight / baseHeight).clamp(0.6, 1.3);
    final double smallScreenScale = isVerySmallScreen ? 0.8 : 1.0;
    final double finalScale = scale * smallScreenScale;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((isLargeTablet ? 28.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 16.0 : 20.0))) * finalScale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular((isTablet ? 20 : 16) * finalScale),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
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
                size: (isTablet ? 24 : 20) * finalScale,
              ),
              SizedBox(width: 8 * finalScale),
              Expanded(
                child: Text(
                  'Quick Stats Overview',
                  style: TextStyle(
                    fontSize: (isTablet ? 20 : 18) * finalScale,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16 * finalScale),
          
          // Stats Grid
          if (_statsLoading)
            _buildStatsLoading(isTablet, isSmallPhone, isLandscape, finalScale)
          else
            _buildStatsGrid(isTablet, isSmallPhone, isLandscape, finalScale),
        ],
      ),
    );
  }

  Widget _buildStatsLoading(bool isTablet, bool isSmallPhone, bool isLandscape, double finalScale) {
    return Container(
      height: (isTablet ? 80 : 70) * finalScale,
      child: Row(
        children: List.generate(4, (index) => 
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4 * finalScale),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12 * finalScale),
              ),
              child: Center(
                child: SizedBox(
                  width: (isTablet ? 24 : 20) * finalScale,
                  height: (isTablet ? 24 : 20) * finalScale,
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

  Widget _buildStatsGrid(bool isTablet, bool isSmallPhone, bool isLandscape, double finalScale) {
    // For very small phones or landscape mode, use 2x2 grid
    if (isSmallPhone || (isLandscape && !isTablet)) {
      return Column(
        children: [
          // First row
          Row(
            children: [
              Expanded(
                child: _buildOverviewStatCard(
                  'Today\'s\nInspections',
                  _todayInspections.toString(),
                  Icons.calendar_today_outlined,
                  const Color.fromRGBO(8, 111, 222, 0.977),
                  isTablet,
                  finalScale,
                ),
              ),
              SizedBox(width: 8 * finalScale),
              Expanded(
                child: _buildOverviewStatCard(
                  'Pending\nAssignments',
                  _pendingAssignments.toString(),
                  Icons.pending_actions_outlined,
                  const Color(0xFFF59E0B),
                  isTablet,
                  finalScale,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * finalScale),
          // Second row
          Row(
            children: [
              Expanded(
                child: _buildOverviewStatCard(
                  'Completed\nThis Week',
                  _weeklyCompleted.toString(),
                  Icons.check_circle_outline,
                  const Color(0xFF10B981),
                  isTablet,
                  finalScale,
                ),
              ),
              SizedBox(width: 8 * finalScale),
              Expanded(
                child: _buildOverviewStatCard(
                  'Sync\nStatus',
                  _hasOfflineData ? 'Online' : 'Offline',
                  _hasOfflineData ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  _hasOfflineData ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  isTablet,
                  finalScale,
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    // For tablets and larger phones, use horizontal layout
    return Row(
      children: [
        // Today's Inspections
        Expanded(
          child: _buildOverviewStatCard(
            'Today\'s\nInspections',
            _todayInspections.toString(),
            Icons.calendar_today_outlined,
            const Color.fromRGBO(8, 111, 222, 0.977),
            isTablet,
            finalScale,
          ),
        ),
        SizedBox(width: 8 * finalScale),
        
        // Pending Assignments
        Expanded(
          child: _buildOverviewStatCard(
            'Pending\nAssignments',
            _pendingAssignments.toString(),
            Icons.pending_actions_outlined,
            const Color(0xFFF59E0B),
            isTablet,
            finalScale,
          ),
        ),
        SizedBox(width: 8 * finalScale),
        
        // Weekly Completed
        Expanded(
          child: _buildOverviewStatCard(
            'Completed\nThis Week',
            _weeklyCompleted.toString(),
            Icons.check_circle_outline,
            const Color(0xFF10B981),
            isTablet,
            finalScale,
          ),
        ),
        SizedBox(width: 8 * finalScale),
        
        // Sync Status
        Expanded(
          child: _buildOverviewStatCard(
            'Sync\nStatus',
            _hasOfflineData ? 'Online' : 'Offline',
            _hasOfflineData ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            _hasOfflineData ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            isTablet,
            finalScale,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewStatCard(String title, String value, IconData icon, Color color, bool isTablet, double finalScale) {
    return Container(
      padding: EdgeInsets.all((isTablet ? 16 : 12) * finalScale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular((isTablet ? 16 : 12) * finalScale),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: (isTablet ? 24 : 20) * finalScale,
          ),
          SizedBox(height: 8 * finalScale),
          Text(
            value,
            style: TextStyle(
              fontSize: (isTablet ? 20 : 18) * finalScale,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4 * finalScale),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: (isTablet ? 12 : 10) * finalScale,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

}