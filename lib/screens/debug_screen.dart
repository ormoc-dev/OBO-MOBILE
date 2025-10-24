import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/network_utils.dart';
import '../utils/url_tester.dart';
import '../config/app_config.dart';
import '../services/offline_sync_service.dart';
import '../services/auth_service.dart';
import '../services/hive_offline_database.dart';
import 'dart:io';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  bool _isLoading = false;
  String _connectionStatus = 'Not tested';
  String _localIp = 'Unknown';
  String _wifiSSID = 'Unknown';
  String _networkType = 'Unknown';
  String _connectionLatency = 'Not tested';
  SyncStatus? _offlineStatus;
  bool _hasOfflineCredentials = false;
  String _hiveDebugInfo = 'Not checked';
  String _currentBaseUrl = '';
  String _selectedEnvironment = 'Local';
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  List<Map<String, dynamic>> _apiLogs = [];
  List<String> _errorLogs = [];
  Map<String, dynamic> _environmentConfig = <String, dynamic>{};
  Map<String, dynamic> _localStorage = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _getLocalIp();
    _loadOfflineStatus();
    _loadUserInfo();
    _loadHiveDebugInfo();
    _loadCustomIp();
    _loadNetworkInfo();
    _loadEnvironmentConfig();
    _loadLocalStorage();
    _loadErrorLogs();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineStatus() async {
    final status = await OfflineSyncService.getSyncStatus();
    setState(() {
      _offlineStatus = status;
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final hasCredentials = await OfflineSyncService.hasOfflineCredentials();
      
      setState(() {
        _hasOfflineCredentials = hasCredentials;
      });
    } catch (e) {
      setState(() {
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

  Future<void> _loadNetworkInfo() async {
    try {
      // Get network interface information
      final interfaces = await NetworkInterface.list();
      String wifiSSID = 'Unknown';
      String networkType = 'Unknown';
      
      for (var interface in interfaces) {
        if (interface.name.toLowerCase().contains('wifi') || 
            interface.name.toLowerCase().contains('wlan')) {
          networkType = 'WiFi';
          break;
        } else if (interface.name.toLowerCase().contains('ethernet') ||
                   interface.name.toLowerCase().contains('eth')) {
          networkType = 'Ethernet';
          break;
        }
      }
      
      setState(() {
        _wifiSSID = wifiSSID;
        _networkType = networkType;
      });
    } catch (e) {
      setState(() {
        _wifiSSID = 'Error: $e';
        _networkType = 'Error: $e';
      });
    }
  }

  Future<void> _loadEnvironmentConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final config = <String, dynamic>{};
      
      for (String key in keys) {
        final value = prefs.get(key);
        config[key] = value;
      }
      
      setState(() {
        _environmentConfig = config;
      });
    } catch (e) {
      setState(() {
        _environmentConfig = {'error': 'Failed to load: $e'};
      });
    }
  }

  Future<void> _loadLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final storage = <String, dynamic>{};
      
      for (String key in keys) {
        final value = prefs.get(key);
        storage[key] = value;
      }
      
      setState(() {
        _localStorage = storage;
      });
    } catch (e) {
      setState(() {
        _localStorage = {'error': 'Failed to load: $e'};
      });
    }
  }

  Future<void> _loadErrorLogs() async {
    // Simulate error logs - in a real app, you'd load from a logging service
    setState(() {
      _errorLogs = [
        '2024-01-15 10:30:15 - Network timeout on API call',
        '2024-01-15 10:25:42 - Failed to sync offline data',
        '2024-01-15 10:20:18 - Authentication token expired',
        '2024-01-15 10:15:33 - Database connection lost',
      ];
    });
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied to clipboard: $text'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testConnectionWithLatency() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stopwatch = Stopwatch()..start();
      final urlTest = await UrlTester.testApiUrl();
      stopwatch.stop();
      
      final latency = stopwatch.elapsedMilliseconds;
      
      setState(() {
        _connectionLatency = '${latency}ms';
        if (urlTest['success'] == true) {
          _connectionStatus = 'API server is reachable ✅\n${urlTest['message']}\nLatency: ${latency}ms';
        } else {
          _connectionStatus = 'API server not reachable ❌\n${urlTest['message']}\nLatency: ${latency}ms';
        }
        _isLoading = false;
      });
      
      // Add to API logs
      setState(() {
        _apiLogs.insert(0, {
          'timestamp': DateTime.now().toString(),
          'url': _currentBaseUrl,
          'status': urlTest['success'] ? 'SUCCESS' : 'FAILED',
          'latency': '${latency}ms',
          'response': urlTest['message'],
        });
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: $e';
        _connectionLatency = 'Error';
        _isLoading = false;
      });
      
      // Add error to logs
      setState(() {
        _errorLogs.insert(0, '${DateTime.now()} - Connection test failed: $e');
      });
    }
  }

  Future<void> _saveCustomUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_base_url', url);
    setState(() {
      _currentBaseUrl = url;
    });
  }

  void _setEnvironment(String environment) {
    setState(() {
      _selectedEnvironment = environment;
    });
    
    String baseUrl;
    switch (environment) {
      case 'Local':
        baseUrl = 'http://$_localIp/obo-lgu/api';
        break;
      case 'Staging':
        baseUrl = 'https://staging-api.obo.com/api';
        break;
      case 'Production':
        baseUrl = 'https://api.obo.com/api';
        break;
      default:
        baseUrl = _currentBaseUrl;
    }
    
    _urlController.text = baseUrl;
    _saveCustomUrl(baseUrl);
  }

  Future<void> _loadCustomIp() async {
    final prefs = await SharedPreferences.getInstance();
    final customIp = prefs.getString('custom_ip') ?? '';
    final currentBaseUrl = await AppConfig.baseUrl;
    
    setState(() {
      _currentBaseUrl = currentBaseUrl;
      _ipController.text = customIp;
      _urlController.text = currentBaseUrl;
    });
  }


  Future<void> _testConnection() async {
    await _testConnectionWithLatency();
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
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
    // Dynamic scaling
    final double baseHeight = isLandscape ? 600.0 : 800.0;
    final double scale = (screenHeight / baseHeight).clamp(0.6, 1.3);
    final double smallScreenScale = isVerySmallScreen ? 0.8 : 1.0;
    final double finalScale = scale * smallScreenScale;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '🧩 Debug & Network Tools',
          style: TextStyle(
            fontSize: (isLargeTablet ? 22.0 : (isTablet ? 20.0 : (isVerySmallScreen ? 16.0 : 18.0))) * finalScale,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadOfflineStatus();
              _loadUserInfo();
              _loadHiveDebugInfo();
              _loadNetworkInfo();
              _loadEnvironmentConfig();
              _loadLocalStorage();
            },
          ),
        ],
      ),
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
            padding: EdgeInsets.all((isLargeTablet ? 32.0 : (isTablet ? 28.0 : (isVerySmallScreen ? 16.0 : 24.0))) * finalScale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Network Status Overview
                _buildSectionHeader('🌐 Network Status', Icons.wifi),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard('Local IP', _localIp, onTap: () => _copyToClipboard(_localIp)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard('Network Type', _networkType),
                    ),
                  ],
                ),
                
                _buildInfoCard('WiFi SSID', _wifiSSID),
                _buildInfoCard('Connection Status', _connectionStatus),
                _buildInfoCard('Latency', _connectionLatency),
                
                const SizedBox(height: 24),
                
                // Environment & URL Configuration
                _buildSectionHeader('⚙️ Environment Configuration', Icons.settings),
                const SizedBox(height: 16),
                
                _buildEnvironmentSelector(),
                const SizedBox(height: 16),
                
                _buildUrlConfiguration(),
                const SizedBox(height: 24),
                
                // API Testing
                _buildSectionHeader('🔍 API Testing', Icons.api),
                const SizedBox(height: 16),
                
                _buildApiTestSection(),
                const SizedBox(height: 24),
                
                // Developer Tools
                _buildSectionHeader('🛠️ Developer Tools', Icons.developer_mode),
                const SizedBox(height: 16),
                
                _buildDeveloperTools(),
                const SizedBox(height: 24),
                
                // Offline Data Status
                _buildSectionHeader('💾 Offline Data Status', Icons.storage),
                const SizedBox(height: 16),
                
                _buildOfflineDataSection(),
                const SizedBox(height: 24),
                
                // Troubleshooting
                _buildSectionHeader('🔧 Troubleshooting', Icons.build),
                const SizedBox(height: 16),
                
                _buildTroubleshootingSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 2),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  const Icon(
                    Icons.copy,
                    size: 16,
                    color: Color.fromRGBO(8, 111, 222, 0.977),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color.fromRGBO(8, 111, 222, 0.977),
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildEnvironmentSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Environment Presets',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildEnvironmentButton('Local', Icons.home),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEnvironmentButton('Staging', Icons.developer_mode),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEnvironmentButton('Production', Icons.cloud),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentButton(String environment, IconData icon) {
    final isSelected = _selectedEnvironment == environment;
    return ElevatedButton(
      onPressed: () => _setEnvironment(environment),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected 
            ? const Color.fromRGBO(8, 111, 222, 0.977)
            : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            environment,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlConfiguration() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              const Icon(
                Icons.link,
                color: Color.fromRGBO(8, 111, 222, 0.977),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Custom Base URL',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'e.g., http://192.168.1.100:8000/api',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color.fromRGBO(8, 111, 222, 0.977), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final url = _urlController.text.trim();
                  await _saveCustomUrl(url);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('URL saved: $url'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _copyToClipboard(_currentBaseUrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7280),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Copy URL',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _copyToClipboard(_localIp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Copy IP',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApiTestSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Text(
            'API Connection Test',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _testConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Test Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _copyToClipboard(_connectionStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7280),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Icon(
                  Icons.copy,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperTools() {
    return Column(
      children: [
        _buildDeveloperToolCard(
          'Environment Variables',
          Icons.settings_applications,
          _environmentConfig.isNotEmpty 
              ? '${_environmentConfig.length} variables loaded'
              : 'No environment variables',
          () => _showEnvironmentDialog(),
        ),
        _buildDeveloperToolCard(
          'Local Storage',
          Icons.storage,
          _localStorage.isNotEmpty 
              ? '${_localStorage.length} items stored'
              : 'No local storage',
          () => _showStorageDialog(),
        ),
        _buildDeveloperToolCard(
          'API Logs',
          Icons.api,
          '${_apiLogs.length} requests logged',
          () => _showApiLogsDialog(),
        ),
        _buildDeveloperToolCard(
          'Error Console',
          Icons.bug_report,
          '${_errorLogs.length} errors logged',
          () => _showErrorLogsDialog(),
        ),
      ],
    );
  }

  Widget _buildDeveloperToolCard(String title, IconData icon, String subtitle, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: const Color.fromRGBO(8, 111, 222, 0.977),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineDataSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              const Icon(
                Icons.storage,
                color: Color.fromRGBO(8, 111, 222, 0.977),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Offline Data Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
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
              color: Color(0xFF1F2937),
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
              color: Color(0xFF6B7280),
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
                    _loadHiveDebugInfo();
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
    );
  }

  Widget _buildTroubleshootingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Common Issues & Solutions:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 12),
          Text(
            '• API Connection Failed: Check XAMPP is running\n'
            '• Wrong IP Address: Update baseUrl in app_config.dart\n'
            '• No Offline Data: Login online and sync first\n'
            '• Can\'t Login Offline: Check credentials were stored\n'
            '• Sync Failed: Check user has assignments in database\n'
            '• Network Issues: Try different IP or check firewall\n'
            '• App Crashes: Clear app data and restart',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showEnvironmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Environment Variables'),
        content: SizedBox(
          width: double.maxFinite,
          child: _environmentConfig.isNotEmpty 
            ? ListView.builder(
                shrinkWrap: true,
                itemCount: _environmentConfig.length,
                itemBuilder: (context, index) {
                  final key = _environmentConfig.keys.elementAt(index);
                  final value = _environmentConfig[key];
                  return ListTile(
                    title: Text(key),
                    subtitle: Text(value.toString()),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyToClipboard('$key: $value'),
                    ),
                  );
                },
              )
            : const Text('No environment variables found'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStorageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Local Storage'),
        content: SizedBox(
          width: double.maxFinite,
          child: _localStorage.isNotEmpty 
            ? ListView.builder(
                shrinkWrap: true,
                itemCount: _localStorage.length,
                itemBuilder: (context, index) {
                  final key = _localStorage.keys.elementAt(index);
                  final value = _localStorage[key];
                  return ListTile(
                    title: Text(key),
                    subtitle: Text(value.toString()),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyToClipboard('$key: $value'),
                    ),
                  );
                },
              )
            : const Text('No local storage found'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showApiLogsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Request Logs'),
        content: SizedBox(
          width: double.maxFinite,
          child: _apiLogs.isNotEmpty 
            ? ListView.builder(
                shrinkWrap: true,
                itemCount: _apiLogs.length,
                itemBuilder: (context, index) {
                  final log = _apiLogs[index];
                  return Card(
                    child: ListTile(
                      title: Text('${log['status']} - ${log['latency']}'),
                      subtitle: Text('${log['url']}\n${log['timestamp']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyToClipboard(log.toString()),
                      ),
                    ),
                  );
                },
              )
            : const Text('No API logs found'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showErrorLogsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Console'),
        content: SizedBox(
          width: double.maxFinite,
          child: _errorLogs.isNotEmpty 
            ? ListView.builder(
                shrinkWrap: true,
                itemCount: _errorLogs.length,
                itemBuilder: (context, index) {
                  final error = _errorLogs[index];
                  return Card(
                    child: ListTile(
                      title: Text(error),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyToClipboard(error),
                      ),
                    ),
                  );
                },
              )
            : const Text('No error logs found'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
