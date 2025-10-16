import 'package:flutter/material.dart';
import '../utils/network_utils.dart';
import '../utils/url_tester.dart';
import '../config/app_config.dart';
import '../services/offline_sync_service.dart';
import '../services/auth_service.dart';
import '../services/hive_offline_database.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  bool _isLoading = false;
  String _connectionStatus = 'Not tested';
  String _localIp = 'Unknown';
  SyncStatus? _offlineStatus;
  bool _hasOfflineCredentials = false;
  String _currentUser = 'Not logged in';
  String _hiveDebugInfo = 'Not checked';

  @override
  void initState() {
    super.initState();
    _getLocalIp();
    _loadOfflineStatus();
    _loadUserInfo();
    _loadHiveDebugInfo();
  }

  Future<void> _loadOfflineStatus() async {
    final status = await OfflineSyncService.getSyncStatus();
    setState(() {
      _offlineStatus = status;
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await AuthService.getCurrentUser();
      final hasCredentials = await OfflineSyncService.hasOfflineCredentials();
      
      setState(() {
        _currentUser = user?.name ?? 'Not logged in';
        _hasOfflineCredentials = hasCredentials;
      });
    } catch (e) {
      setState(() {
        _currentUser = 'Error loading user info';
        _hasOfflineCredentials = false;
      });
    }
  }

  Future<void> _loadHiveDebugInfo() async {
    try {
      final hiveUser = HiveOfflineDatabase.getCurrentUser();
      final assignments = HiveOfflineDatabase.getAssignments();
      final hasData = HiveOfflineDatabase.hasOfflineData();
      
      setState(() {
        _hiveDebugInfo = 'User: ${hiveUser?.name ?? 'null'}\n'
                        'Assignments: ${assignments.length}\n'
                        'Has Data: $hasData';
      });
    } catch (e) {
      setState(() {
        _hiveDebugInfo = 'Error: $e';
      });
    }
  }

  Future<void> _getLocalIp() async {
    final ip = await NetworkUtils.getLocalIpAddress();
    setState(() {
      _localIp = ip ?? 'Unknown';
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Test the specific API URL
      final urlTest = await UrlTester.testApiUrl();

      setState(() {
        if (urlTest['success'] == true) {
          _connectionStatus = 'API server is reachable ✅\n${urlTest['message']}';
        } else {
          _connectionStatus = 'API server not reachable ❌\n${urlTest['message']}';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: $e';
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Information'),
        backgroundColor: const Color(0xFFE0E5EC),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0E5EC),
              Color(0xFFF0F4F8),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Network Configuration',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 20),
                
                _buildInfoCard('API Base URL', AppConfig.baseUrl),
                _buildInfoCard('Local IP Address', _localIp),
                _buildInfoCard('Connection Status', _connectionStatus),
                _buildInfoCard('Current User', _currentUser),
                
                const SizedBox(height: 30),
                
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _testConnection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A5568),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Test API Connection',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          _loadOfflineStatus();
                          _loadUserInfo();
                          _loadHiveDebugInfo();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D3748),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Offline Data Status Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E5EC),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFA3B1C6),
                        offset: Offset(4, 4),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.white,
                        offset: Offset(-4, -4),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.storage,
                            color: Color(0xFF4A5568),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Offline Data Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Offline Data Status
                      if (_offlineStatus != null) ...[
                        _buildInfoCard(
                          'Offline Data', 
                          _offlineStatus!.hasData ? 'Available ✅' : 'Not Available ❌'
                        ),
                        _buildInfoCard(
                          'Last Sync', 
                          _offlineStatus!.lastSync?.toString().substring(0, 19) ?? 'Never'
                        ),
                        _buildInfoCard(
                          'Offline Login', 
                          _hasOfflineCredentials ? 'Available ✅' : 'Not Available ❌'
                        ),
                        _buildInfoCard(
                          'Sync Status', 
                          _offlineStatus!.isSuccess ? 'Success ✅' : 'Failed ❌'
                        ),
                        _buildInfoCard(
                          'Hive Database', 
                          _hiveDebugInfo
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Offline Workflow:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Login online first\n'
                        '2. Click "Sync My Data" in dashboard\n'
                        '3. Turn off internet/WiFi\n'
                        '4. Logout and login again\n'
                        '5. You can now access data offline!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4A5568),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Clear All Data'),
                                content: const Text(
                                  'This will clear all offline data including synced assignments and credentials. You will need to sync again to use offline features.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Clear All'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (confirmed == true) {
                              try {
                                await AuthService.logoutAndClearAll();
                                _loadOfflineStatus();
                                _loadUserInfo();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('All data cleared successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error clearing data: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53E3E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Clear All Data',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                const Text(
                  'Troubleshooting:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 10),
                
                const Text(
                  '• API Connection Failed: Check XAMPP is running\n'
                  '• Wrong IP Address: Update baseUrl in app_config.dart\n'
                  '• No Offline Data: Login online and sync first\n'
                  '• Can\'t Login Offline: Check credentials were stored\n'
                  '• Sync Failed: Check user has assignments in database',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A5568),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E5EC),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFA3B1C6),
            offset: Offset(2, 2),
            blurRadius: 4,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-2, -2),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5568),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }
}
