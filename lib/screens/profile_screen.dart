import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/offline_sync_service.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser;
  bool isLoading = true;
  bool _hasOfflineData = false;
  bool _hasOfflineCredentials = false;
  String _lastSyncTime = 'Never';

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      final syncStatus = await OfflineSyncService.getSyncStatus();
      final hasOfflineData = await OfflineSyncService.hasOfflineData();
      final hasCredentials = await OfflineSyncService.hasOfflineCredentials();
      
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
      setState(() {
        _lastSyncTime = 'Error';
      });
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
    final isTablet = screenWidth > 600;

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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 32.0 : 16.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with back button
                _buildHeader(context, isTablet),
                
                const SizedBox(height: 24),
                
                // Account Information
                _buildAccountInfo(context, isTablet),
                
                const SizedBox(height: 24),
                
                // Sync Status
                _buildSyncStatus(context, isTablet),
                
                const SizedBox(height: 24),
                
                // Settings Options
                _buildSettingsOptions(context, isTablet),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet) {
    return Row(
      children: [
        
        const SizedBox(width: 16),
        Text(
          'Profile & Settings',
          style: TextStyle(
            fontSize: isTablet ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountInfo(BuildContext context, bool isTablet) {
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: const Color.fromRGBO(8, 111, 222, 0.977),
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Text(
                'Account Information',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          
          SizedBox(height: isTablet ? 20 : 16),
          
          _buildInfoRow('User ID', currentUser?.id.toString() ?? 'N/A', isTablet),
          _buildInfoRow('Name', currentUser?.name ?? 'N/A', isTablet),
          _buildInfoRow('Role', currentUser?.role ?? 'N/A', isTablet),
          _buildInfoRow('Inspector Role', currentUser?.inspectorRole ?? 'N/A', isTablet),
          _buildInfoRow('Status', currentUser?.status ?? 'N/A', isTablet),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isTablet) {
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 12 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isTablet ? 120 : 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: const Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatus(BuildContext context, bool isTablet) {
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
              Text(
                'Data Sync Status',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          
          SizedBox(height: isTablet ? 20 : 16),
          
          _buildSyncInfoRow('Offline Data', _hasOfflineData ? 'Available' : 'Not Available', _hasOfflineData ? Colors.green : Colors.red, isTablet),
          _buildSyncInfoRow('Offline Login', _hasOfflineCredentials ? 'Available' : 'Not Available', _hasOfflineCredentials ? Colors.green : Colors.red, isTablet),
          _buildSyncInfoRow('Last Sync', _lastSyncTime, _lastSyncTime == 'Never' ? Colors.grey : const Color.fromRGBO(8, 111, 222, 0.977), isTablet),
        ],
      ),
    );
  }

  Widget _buildSyncInfoRow(String label, String value, Color color, bool isTablet) {
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 12 : 10),
      child: Row(
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
      ),
    );
  }

  Widget _buildSettingsOptions(BuildContext context, bool isTablet) {
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Icon(
                  Icons.settings_rounded,
                  color: const Color.fromRGBO(8, 111, 222, 0.977),
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          
          SizedBox(height: isTablet ? 20 : 16),
          
          _buildSettingsItem(
            'Notifications',
            'Manage your notification preferences',
            Icons.notifications_rounded,
            const Color(0xFF06B6D4),
            () {
              // Navigate to notifications settings
            },
            isTablet,
          ),
          
          _buildSettingsItem(
            'Privacy & Security',
            'Manage your privacy and security settings',
            Icons.security_rounded,
            const Color(0xFF10B981),
            () {
              // Navigate to privacy settings
            },
            isTablet,
          ),
          
          _buildSettingsItem(
            'Help & Support',
            'Get help and contact support',
            Icons.help_rounded,
            const Color(0xFFEF4444),
            () {
              // Navigate to help
            },
            isTablet,
          ),
          
          _buildSettingsItem(
            'About',
            'App version and information',
            Icons.info_rounded,
            const Color(0xFF6B7280),
            () {
              // Show about dialog
            },
            isTablet,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool isTablet,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isTablet ? 20 : 18,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: const Color(0xFF6B7280),
                  size: isTablet ? 16 : 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
}
