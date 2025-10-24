import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/offline_sync_service.dart';
import '../models/user.dart';
import 'assignments_screen.dart';
import 'qr_scanner_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  User? currentUser;
  bool isLoading = true;
  bool _isSyncing = false;
  String _syncStatus = 'Not synced';
  bool _hasOfflineData = false;
  bool _hasOfflineCredentials = false;
  String _lastSyncTime = 'Never';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSyncStatus();
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
        
        if (hasOfflineData && hasCredentials) {
          if (syncStatus.lastSync != null) {
            _syncStatus = 'Last synced: ${syncStatus.lastSync!.toString().substring(0, 19)}';
          } else {
            _syncStatus = 'Data available offline';
          }
        } else if (hasOfflineData) {
          _syncStatus = 'Data synced (no credentials)';
        } else {
          _syncStatus = 'Not synced';
        }
      });
    } catch (e) {
      print('Dashboard: Error loading sync status: $e');
      setState(() {
        _syncStatus = 'Error loading sync status';
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
        if (result.success) {
          _syncStatus = 'Successfully synced ${result.assignmentsCount} assignments';
        } else {
          _syncStatus = 'Sync failed: ${result.message}';
        }
        _isSyncing = false;
      });

      // Refresh sync status to show updated information
      print('Dashboard: Refreshing sync status after sync...');
      await _loadSyncStatus();
      
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
        _syncStatus = 'Sync error: $e';
        _isSyncing = false;
      });
      
      // Refresh sync status even after error
      await _loadSyncStatus();
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
              
              // Quick Stats Cards
              _buildQuickStatsSection(context, isTablet),
              
              const SizedBox(height: 24),
              
              // Main Dashboard Grid
              _buildDashboardGrid(context, isTablet),
              
              const SizedBox(height: 24),
              
              // Sync Status Card (moved to bottom)
              _buildSyncStatusCard(context, isTablet),
              
              const SizedBox(height: 24),
            ],
          ),
          ),
        ),
      ),
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
          child: _buildStatCard(
            'Status',
            currentUser?.status ?? 'Active',
            Icons.verified_user_rounded,
            _getStatusColor(currentUser?.status),
            isTablet,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: _buildStatCard(
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isTablet) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _hasOfflineData ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasOfflineData ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3), 
                    width: 1
                  ),
                ),
                child: Icon(
                  _hasOfflineData ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: _hasOfflineData ? Colors.green : Colors.orange,
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: isTablet ? 12 : 8),
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
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hasOfflineData 
                        ? 'Your data is synced and available offline'
                        : 'Sync your data to work offline',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
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
        // Featured QR Scanner Section
        _buildFeaturedQRScanner(context, isTablet),
        
        SizedBox(height: isTablet ? 32 : 24),
        
        // Quick Actions Section
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: isTablet ? 20 : 16),
        
        // Primary Actions Row
        Row(
          children: [
            Expanded(
              child: _buildModernDashboardCard(
                'Assigned Inspections',
                Icons.assignment_rounded,
                const Color(0xFF3B82F6),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AssignmentsScreen(),
                    ),
                  );
                },
                isTablet,
              ),
            ),
            SizedBox(width: isTablet ? 20 : 16),
            Expanded(
              child: _buildModernDashboardCard(
                'Sync My Data',
                Icons.sync_rounded,
                const Color(0xFF10B981),
                _isSyncing ? null : _fetchUserData,
                isTablet,
                isLoading: _isSyncing,
                statusText: _syncStatus,
              ),
            ),
          ],
        ),
        
        SizedBox(height: isTablet ? 20 : 16),
        
        // Secondary Actions Row
        Row(
          children: [
            Expanded(
              child: _buildModernDashboardCard(
                'Inspection Reports',
                Icons.assessment_rounded,
                const Color(0xFFF59E0B),
                () {
                  // Navigate to inspection reports
                },
                isTablet,
              ),
            ),
            SizedBox(width: isTablet ? 20 : 16),
            Expanded(
              child: _buildModernDashboardCard(
                'Profile & Settings',
                Icons.person_rounded,
                const Color(0xFF6366F1),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                isTablet,
              ),
            ),
          ],
        ),
        
        // Additional actions for tablet
        if (isTablet) ...[
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildModernDashboardCard(
                  'Help & Support',
                  Icons.help_rounded,
                  const Color(0xFFEF4444),
                  () {
                    // Navigate to help and support
                  },
                  isTablet,
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: _buildModernDashboardCard(
                  'Notifications',
                  Icons.notifications_rounded,
                  const Color(0xFF06B6D4),
                  () {
                    // Navigate to notifications
                  },
                  isTablet,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFeaturedQRScanner(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 28 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(8, 111, 222, 0.977), // Purple
            Color.fromRGBO(22, 127, 239, 0.976), // Indigo
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(123, 168, 216, 0.976),
            offset: Offset(0, 4),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QR Code Scanner',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scan business QR codes for quick inspection access',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 24 : 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToQRScanner,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color.fromARGB(255, 29, 109, 228),
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 16 : 14,
                  horizontal: isTablet ? 32 : 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  SizedBox(width: isTablet ? 12 : 8),
                  Text(
                    'Start Scanning',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDashboardCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap,
    bool isTablet, {
    bool isLoading = false,
    String? statusText,
  }) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: isTablet ? 32 : 28,
                          height: isTablet ? 32 : 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                      : Icon(
                          icon,
                          size: isTablet ? 32 : 28,
                          color: color,
                        ),
                ),
                SizedBox(height: isTablet ? 16 : 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (statusText != null && statusText.isNotEmpty) ...[
                  SizedBox(height: isTablet ? 8 : 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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

  void _navigateToQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
  }

}