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
  String _connectionLatency = 'Not tested';
  SyncStatus? _offlineStatus;
  bool _hasOfflineCredentials = false;
  String _hiveDebugInfo = 'Not checked';
  String _currentBaseUrl = '';
  String _currentIp = '';
  String _networkInterfacesInfo = 'Not loaded';
  final TextEditingController _ipController = TextEditingController();
  List<Map<String, dynamic>> _apiLogs = [];
  List<String> _errorLogs = [];
  // Chatbot state
  bool _isChatbotOpen = false;
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _getLocalIp();
    _loadOfflineStatus();
    _loadUserInfo();
    _loadHiveDebugInfo();
    _loadCustomIp();
    _loadNetworkInterfaces();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
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
    setState(() {
      _localIp = 'Loading...';
    });
    
    try {
      final ip = await NetworkUtils.getLocalIpAddress();
      setState(() {
        _localIp = ip ?? 'No IPv4 address found';
      });
    } catch (e) {
      setState(() {
        _localIp = 'Error: $e';
      });
    }
  }


  Future<void> _loadNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list();
      StringBuffer info = StringBuffer();
      
      info.writeln('Found ${interfaces.length} network interfaces:');
      info.writeln();
      
      for (var interface in interfaces) {
        info.writeln('Interface: ${interface.name}');
        info.writeln('  Index: ${interface.index}');
        info.writeln('  Addresses: ${interface.addresses.length}');
        
        for (var addr in interface.addresses) {
          info.writeln('    - ${addr.address} (${addr.type})');
          info.writeln('      Loopback: ${addr.isLoopback}');
        }
        info.writeln();
      }
      
      setState(() {
        _networkInterfacesInfo = info.toString();
      });
    } catch (e) {
      setState(() {
        _networkInterfacesInfo = 'Error loading interfaces: $e';
      });
    }
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
      // Refresh the current base URL from AppConfig before testing
      final currentBaseUrl = await AppConfig.baseUrl;
      setState(() {
        _currentBaseUrl = currentBaseUrl;
      });
      
      final stopwatch = Stopwatch()..start();
      final urlTest = await UrlTester.testApiUrl();
      stopwatch.stop();
      
      final latency = stopwatch.elapsedMilliseconds;
      final testedUrl = urlTest['url'] as String? ?? currentBaseUrl;
      
      setState(() {
        _connectionLatency = '${latency}ms';
        if (urlTest['success'] == true) {
          _connectionStatus = 'API server is reachable ✅\n${urlTest['message']}\nTested URL: $testedUrl\nLatency: ${latency}ms';
        } else {
          _connectionStatus = 'API server not reachable ❌\n${urlTest['message']}\nTested URL: $testedUrl\nLatency: ${latency}ms';
        }
        _isLoading = false;
      });
      
      // Add to API logs
      setState(() {
        _apiLogs.insert(0, {
          'timestamp': DateTime.now().toString(),
          'url': testedUrl,
          'status': urlTest['success'] ? 'SUCCESS' : 'FAILED',
          'latency': '${latency}ms',
          'response': urlTest['message'],
        });
      });
    } catch (e) {
      // Refresh the current base URL even on error
      try {
        final currentBaseUrl = await AppConfig.baseUrl;
        setState(() {
          _currentBaseUrl = currentBaseUrl;
        });
      } catch (_) {}
      
      setState(() {
        _connectionStatus = 'Error: $e\nPlease check if the IP address is correctly configured.';
        _connectionLatency = 'Error';
        _isLoading = false;
      });
      
      // Add error to logs
      setState(() {
        _errorLogs.insert(0, '${DateTime.now()} - Connection test failed: $e');
      });
    }
  }

  Future<void> _saveCustomIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_ip', ip);
    final baseUrl = 'http://$ip/OBO-LGU/api';
    await prefs.setString('custom_base_url', baseUrl);
    
    // Reload the URL from AppConfig to ensure consistency
    final refreshedBaseUrl = await AppConfig.baseUrl;
    
    setState(() {
      _currentIp = ip;
      _currentBaseUrl = refreshedBaseUrl;
    });
  }


  Future<void> _loadCustomIp() async {
    final prefs = await SharedPreferences.getInstance();
    final customIp = prefs.getString('custom_ip') ?? '';
    final currentBaseUrl = await AppConfig.baseUrl;
    
    // Extract IP from current base URL
    String currentIp = '';
    if (currentBaseUrl.contains('http://')) {
      final parts = currentBaseUrl.split('http://')[1].split('/')[0];
      currentIp = parts;
    }
    
    setState(() {
      _currentBaseUrl = currentBaseUrl;
      _currentIp = currentIp;
      _ipController.text = customIp.isEmpty ? currentIp : customIp;
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
              _getLocalIp();
              _loadOfflineStatus();
              _loadUserInfo();
              _loadHiveDebugInfo();
              _loadNetworkInterfaces();
              _loadCustomIp();
            },
          ),
        ],
      ),
      floatingActionButton: _isChatbotOpen ? null : _buildChatbotFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          // Main content
          Container(
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
                    
                    _buildInfoCard('Local IP', _localIp, onTap: () => _copyToClipboard(_localIp)),
                    
                    // IP Address Retry Button and Manual Input
                    if (_localIp == 'No IPv4 address found' || _localIp.startsWith('Error:'))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _getLocalIp,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry IP Detection'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: '192.168.0.115'),
                                    decoration: const InputDecoration(
                                      labelText: 'Manual IP (from ipconfig)',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onSubmitted: (value) {
                                      if (value.isNotEmpty) {
                                        setState(() {
                                          _localIp = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final controller = TextEditingController(text: '192.168.0.115');
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Set Manual IP'),
                                        content: TextField(
                                          controller: controller,
                                          decoration: const InputDecoration(
                                            labelText: 'IP Address',
                                            hintText: 'e.g., 192.168.0.115',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _localIp = controller.text;
                                              });
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Set'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Set Manual'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    _buildInfoCard('Connection Status', _connectionStatus),
                    _buildInfoCard('Latency', _connectionLatency),
                    
                    const SizedBox(height: 24),
                    
                    // IP Configuration
                    _buildSectionHeader('⚙️ Server Configuration', Icons.settings),
                    const SizedBox(height: 16),
                    
                    _buildIpConfiguration(),
                    const SizedBox(height: 24),
                    
                    // API Testing
                    _buildSectionHeader('🔍 API Testing', Icons.api),
                    const SizedBox(height: 16),
                    
                    _buildApiTestSection(),
                    const SizedBox(height: 24),
                    
                    // Offline Data Status
                    _buildSectionHeader('💾 Offline Data Status', Icons.storage),
                    const SizedBox(height: 16),
                    
                    _buildOfflineDataSection(),
                    const SizedBox(height: 24),
                    
                    // Network Interfaces Debug Info
                    _buildSectionHeader('🔍 Network Interfaces Debug', Icons.network_check),
                    const SizedBox(height: 16),
                    
                    _buildInfoCard('All Network Interfaces', _networkInterfacesInfo),
                    
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
          // Chatbot overlay
          if (_isChatbotOpen)
            _buildChatbotOverlay(),
        ],
      ),
    );
  }

  Widget _buildChatbotOverlay() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final orientation = MediaQuery.of(context).orientation;
    
    // Enhanced responsive breakpoints
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
    // Responsive dimensions
    final overlayWidth = isLargeTablet 
        ? 600.0 
        : isTablet 
            ? (isLandscape ? screenWidth * 0.6 : 500.0)
            : screenWidth * 0.95;
    
    final overlayHeight = isLandscape
        ? (isLargeTablet ? screenHeight * 0.85 : screenHeight * 0.9)
        : isSmallScreen
            ? (isVerySmallScreen ? screenHeight * 0.85 : screenHeight * 0.8)
            : (isLargeTablet ? screenHeight * 0.75 : screenHeight * 0.8);
    
    final headerPadding = isTablet ? 20.0 : (isSmallScreen ? 12.0 : 16.0);
    final headerIconSize = isTablet ? 28.0 : (isSmallScreen ? 20.0 : 24.0);
    final headerFontSize = isTablet ? 20.0 : (isSmallScreen ? 16.0 : 18.0);
    final messagePadding = isTablet ? 20.0 : (isSmallScreen ? 12.0 : 16.0);
    final inputPadding = isTablet ? 20.0 : (isSmallScreen ? 12.0 : 16.0);
    
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: SafeArea(
          child: Center(
            child: Container(
              width: overlayWidth,
              height: overlayHeight,
              constraints: BoxConstraints(
                maxWidth: overlayWidth,
                maxHeight: overlayHeight,
                minWidth: isTablet ? 400 : 280,
                minHeight: isSmallScreen ? 400 : 500,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(headerPadding),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(8, 111, 222, 0.977),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 10 : 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.psychology,
                            color: Colors.white,
                            size: headerIconSize,
                          ),
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        Expanded(
                          child: Text(
                            'Debug Assistant',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isChatbotOpen = false;
                            });
                          },
                          icon: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: isTablet ? 24 : 20,
                          ),
                          padding: EdgeInsets.all(isTablet ? 12 : 8),
                          constraints: BoxConstraints(
                            minWidth: isTablet ? 48 : 40,
                            minHeight: isTablet ? 48 : 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Messages
                  Expanded(
                    child: ListView.builder(
                      controller: _chatScrollController,
                      padding: EdgeInsets.all(messagePadding),
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final message = _chatMessages[index];
                        return _buildChatMessage(
                          message['text'] as String,
                          message['isUser'] as bool,
                          isTablet: isTablet,
                          isSmallScreen: isSmallScreen,
                        );
                      },
                    ),
                  ),
                  // Input area
                  Container(
                    padding: EdgeInsets.all(inputPadding),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border(
                        top: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: 'Ask about debugging or setup...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: const BorderSide(color: Color.fromRGBO(8, 111, 222, 0.977), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 20 : 16,
                                vertical: isTablet ? 16 : (isSmallScreen ? 10 : 12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              hintStyle: TextStyle(
                                fontSize: isTablet ? 14 : (isSmallScreen ? 12 : 13),
                              ),
                            ),
                            onSubmitted: _sendChatMessage,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(
                              fontSize: isTablet ? 15 : (isSmallScreen ? 13 : 14),
                            ),
                          ),
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(8, 111, 222, 0.977),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => _sendChatMessage(_chatController.text),
                            icon: Icon(
                              Icons.send,
                              color: Colors.white,
                              size: isTablet ? 24 : 20,
                            ),
                            padding: EdgeInsets.all(isTablet ? 12 : 8),
                            constraints: BoxConstraints(
                              minWidth: isTablet ? 48 : 40,
                              minHeight: isTablet ? 48 : 40,
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
        ),
      ),
    );
  }

  Widget _buildChatMessage(String text, bool isUser, {bool isTablet = false, bool isSmallScreen = false}) {
    final iconSize = isTablet ? 24.0 : (isSmallScreen ? 18.0 : 20.0);
    final iconPadding = isTablet ? 10.0 : (isSmallScreen ? 6.0 : 8.0);
    final messagePadding = isTablet 
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
        : (isSmallScreen 
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12));
    final fontSize = isTablet ? 15.0 : (isSmallScreen ? 12.0 : 14.0);
    final spacing = isTablet ? 12.0 : (isSmallScreen ? 8.0 : 10.0);
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            SizedBox(width: spacing),
          ],
          Flexible(
            child: Container(
              padding: messagePadding,
              decoration: BoxDecoration(
                color: isUser
                    ? const Color.fromRGBO(8, 111, 222, 0.977)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF1F2937),
                  fontSize: fontSize,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: spacing),
            Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.person,
                color: const Color(0xFF6B7280),
                size: iconSize,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatbotFAB() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    
    return FloatingActionButton(
      onPressed: () {
        setState(() {
          _isChatbotOpen = !_isChatbotOpen;
          if (_isChatbotOpen && _chatMessages.isEmpty) {
            _chatMessages.add({
              'text': 'Hello! I\'m Anthony your Debug Assistant. How can I help you troubleshoot or set up the app?',
              'isUser': false,
              'timestamp': DateTime.now(),
            });
          }
        });
        if (_isChatbotOpen) {
          // Scroll to bottom after a short delay
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_chatScrollController.hasClients) {
              _chatScrollController.animateTo(
                _chatScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
      backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
      foregroundColor: Colors.white,
      child: Icon(
        Icons.psychology,
        size: isLargeTablet ? 32 : (isTablet ? 28 : 24),
      ),
    );
  }

  void _sendChatMessage(String message) {
    if (message.trim().isEmpty) return;

    // Add user message
    setState(() {
      _chatMessages.add({
        'text': message,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
    });

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Process message and get response
    final response = _processChatMessage(message);
    
    // Add bot response after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _chatMessages.add({
          'text': response,
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
      
      // Scroll to bottom again
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });

    _chatController.clear();
  }

  String _processChatMessage(String message) {
    final lowerMessage = message.toLowerCase();

    // IP Address issues
    if (lowerMessage.contains('ip') || lowerMessage.contains('address') || lowerMessage.contains('what is my ip')) {
      // Check if IP is available
      final hasValidIp = _localIp != 'Unknown' && 
                         _localIp != 'Loading...' && 
                         !_localIp.startsWith('Error:') && 
                         _localIp != 'No IPv4 address found';
      
      // If user asks "what is my ip" or similar, provide actual IP data
      if (lowerMessage.contains('what') || lowerMessage.contains('my ip') || lowerMessage.contains('current ip')) {
        if (hasValidIp) {
          return '''📍 **Your Current IP Address**

**Mobile Device IP:** $_localIp

**Server Configuration:**
- Current Server IP: ${_currentIp.isEmpty ? 'Not configured' : _currentIp}
- Current Base URL: $_currentBaseUrl

**Next Steps:**
1. Make sure your computer's IP matches the server IP above
2. Both devices should be on the same WiFi network
3. Test connection using "Test Connection" button

💡 **Tip:** If server IP is different, update it in "Server Configuration" section above.''';
        } else {
          return '''⚠️ **IP Address Not Available**

**Status:** $_localIp

**Possible Reasons:**
1. ❌ Not connected to WiFi network
2. ❌ Connected to wrong WiFi network
3. ❌ Mobile data is enabled instead of WiFi

**Solutions:**

**Option 1: Connect to Server WiFi**
- Go to your device WiFi settings
- Connect to the same WiFi network as your server/computer
- Return to this app and refresh

**Option 2: Manual IP Configuration**
- Find your computer's IP address (run `ipconfig` in Command Prompt)
- Enter it in "Server IP Address" field above
- Click "Save" button
- Test the connection

**Option 3: Check Network Settings**
- Make sure WiFi is enabled on your device
- Disable mobile data temporarily
- Ensure you're connected to the correct network

💡 **Need Server Configuration Help?** Ask me "server configuration" or "how to setup server" for detailed steps!''';
        }
      }
      
      // General IP help
      if (lowerMessage.contains('not') || lowerMessage.contains('missing') || lowerMessage.contains('show')) {
        if (!hasValidIp) {
          return '''🔧 **IP Address Not Showing**

**Current Status:** $_localIp

**Quick Fixes:**

1. **Connect to Server WiFi** 📶
   - Open device WiFi settings
   - Connect to the same network as your server
   - Return here and click refresh button

2. **Manual IP Input** 🔧
   - Get your computer's IP (run `ipconfig`)
   - Enter it in "Server IP Address" field
   - Click "Save"

3. **Check Network Connection** ✅
   - Ensure WiFi is enabled
   - Disable mobile data
   - Verify correct network

💡 **Not connected to WiFi?** You need to connect to the server's WiFi network first! Ask me "server configuration" for setup help.''';
        }
        return '''🔧 **IP Address Not Showing**

Here's how to fix it:
1. Click "Retry IP Detection" button
2. If it still doesn't work, use manual IP input:
   - Enter your computer's IP (e.g., 192.168.0.115)
   - Click "Set Manual" button
   - You can find your IP by running `ipconfig` in Command Prompt

💡 **Tip:** Make sure your mobile device and computer are on the same WiFi network!''';
      }
      
      // Default IP help
      if (hasValidIp) {
        return '''📍 **IP Address Information**

**Your Mobile IP:** $_localIp
**Server IP:** ${_currentIp.isEmpty ? 'Not configured' : _currentIp}
**Base URL:** $_currentBaseUrl

**To configure server IP:**
1. Find your computer's IP (run `ipconfig` in Command Prompt)
2. Enter it in "Server IP Address" field above
3. Click "Save" button
4. Test connection

**Need help?** Ask me:
- "What is my IP?" - See your current IP
- "Server configuration" - Setup guide
- "Connection failed" - Troubleshooting''';
      } else {
        return '''📍 **IP Address Help**

**Current Status:** $_localIp

**You need to:**
1. **Connect to Server WiFi** 📶
   - Go to WiFi settings
   - Connect to the same network as your server
   - This is required for IP detection

2. **Or Configure Manually** 🔧
   - Get server IP from computer (`ipconfig`)
   - Enter in "Server IP Address" field
   - Click "Save"

**Not connected to WiFi?** You must connect to the server's WiFi network first!

💡 Ask me "server configuration" for complete setup guide.''';
      }
    }

    // Connection issues
    if (lowerMessage.contains('connect') || lowerMessage.contains('server') || lowerMessage.contains('unreachable')) {
      if (lowerMessage.contains('fail') || lowerMessage.contains('error') || lowerMessage.contains('not reachable')) {
        return '''❌ **Connection Failed**

Let's troubleshoot step by step:

1. ✅ **Check XAMPP is running**
   - Make sure Apache is started in XAMPP Control Panel

2. ✅ **Verify IP Address**
   - Check if the IP address is correct
   - Both devices must be on the same network

3. ✅ **Test Connection**
   - Click "Test Connection" button above
   - Check the error message for details

4. ✅ **Firewall Check**
   - Make sure Windows Firewall allows Apache
   - Check if port 80 is not blocked

5. ✅ **Manual IP Method**
   - Use the manual IP input if auto-detection fails

Still having issues? Try restarting XAMPP!''';
      }
      return '''🌐 **Connection Setup**

To connect to the server:
1. Make sure XAMPP Apache is running
2. Configure the correct IP address
3. Test the connection
4. Both devices must be on the same WiFi network

Need help with a specific connection issue?''';
    }

    // Offline/Sync issues
    if (lowerMessage.contains('offline') || lowerMessage.contains('sync') || lowerMessage.contains('data')) {
      if (lowerMessage.contains('no') || lowerMessage.contains('missing') || lowerMessage.contains('empty')) {
        return '''📱 **No Offline Data**

To sync data for offline use:

1. **First Login Online**
   - Connect to WiFi/server network
   - Login with your credentials

2. **Sync Your Data**
   - Go to Dashboard
   - Click "Sync My Data" button
   - Wait for sync to complete

3. **Test Offline**
   - Turn off WiFi/internet
   - Logout and login again
   - You should be able to access your data offline

💡 **Important:** You must sync while online first!''';
      }
      return '''💾 **Offline Data & Sync**

The app supports offline mode:
- Login online first
- Sync your data in dashboard
- Then you can use offline

Having sync issues? Let me know!''';
    }

    // Login issues
    if (lowerMessage.contains('login') || lowerMessage.contains('sign in') || lowerMessage.contains('credential')) {
      if (lowerMessage.contains('fail') || lowerMessage.contains('error') || lowerMessage.contains('cannot')) {
        return '''🔐 **Login Issues**

Troubleshooting steps:

1. **Online Login Failed**
   - Check server connection (use Test Connection)
   - Verify XAMPP is running
   - Check if IP address is correct

2. **Offline Login Failed**
   - Make sure you synced data while online
   - Check if credentials were stored
   - Try syncing again from dashboard

3. **Server Unreachable**
   - Use WiFi connected to server network
   - Or sync data first, then use offline mode

💡 **Tip:** If server is unreachable, the app will automatically try offline login if you have synced data.''';
      }
      return '''👤 **Login Help**

You can login:
- **Online:** When connected to server
- **Offline:** After syncing data online first

Need help with a specific login issue?''';
    }

    // Network issues
    if (lowerMessage.contains('network') || lowerMessage.contains('wifi') || lowerMessage.contains('internet')) {
      return '''📶 **Network Setup**

Network requirements:
1. **Both devices on same WiFi** - Mobile and computer must be on same network
2. **XAMPP running** - Apache server must be active
3. **Correct IP** - Use your computer's local IP address
4. **Firewall** - Windows Firewall should allow Apache

**Common Issues:**
- Can't detect IP → Use manual IP input
- Wrong network → Connect both devices to same WiFi
- Firewall blocking → Allow Apache in Windows Firewall

Need help with a specific network issue?''';
    }

    // Setup/Installation
    if (lowerMessage.contains('setup') || lowerMessage.contains('install') || lowerMessage.contains('config') || lowerMessage.contains('configure')) {
      return '''⚙️ **Setup Guide**

**Initial Setup Steps:**

1. **Install XAMPP**
   - Download and install XAMPP
   - Start Apache service

2. **Configure IP Address**
   - Find your computer's IP (run `ipconfig`)
   - Enter it in Server IP Address field
   - Click Save

3. **Test Connection**
   - Click "Test Connection" button
   - Should show "API server is reachable ✅"

4. **First Login**
   - Login with your credentials
   - Sync data from dashboard

5. **Test Offline Mode**
   - Turn off WiFi
   - Login again (should work offline)

Need help with a specific step?''';
    }

    // API issues
    if (lowerMessage.contains('api') || lowerMessage.contains('endpoint')) {
      return '''🔌 **API Troubleshooting**

API Connection Issues:

1. **Check Server Status**
   - Verify XAMPP Apache is running
   - Check if server responds

2. **Test Connection**
   - Use "Test Connection" button
   - Check latency and status

3. **Verify URL**
   - URL format: http://[IP]/OBO-LGU/api
   - Make sure IP is correct
   - Check URL is accessible

4. **Common Errors**
   - "No host specified" → Check IP configuration
   - "Connection timeout" → Check firewall/network
   - "404 Not Found" → Check API path

Need help with a specific API error?''';
    }

    // General help
    if (lowerMessage.contains('help') || lowerMessage.contains('how') || lowerMessage.contains('what')) {
      return '''🤖 **Debug Assistant Help**

I can help you with:

📱 **Common Topics:**
- IP Address configuration
- Connection issues
- Offline data & sync
- Login problems
- Network setup
- API troubleshooting

**Just ask me:**
- "How do I set up the IP?"
- "Connection failed"
- "Can't login offline"
- "How to sync data?"

Or ask about any specific issue you're facing!''';
    }

    // Contact/Support requests
    if (lowerMessage.contains('contact') || lowerMessage.contains('developer') || lowerMessage.contains('support') || lowerMessage.contains('email') || lowerMessage.contains('phone') || lowerMessage.contains('number')) {
      return '''📞 Contact Information

If you need further assistance, please contact:

👨‍💻 Developer: Anthony Capuyan
📱 Mobile: 09359483634
📧 Email: anthony.capuyan23@gmail.com

Feel free to reach out if you have any questions or need additional help!''';
    }

    // Default response
    return '''🤔 **I'm here to help!**

I can assist with:
- 🔧 IP address setup
- 🌐 Connection issues
- 📱 Offline data & sync
- 🔐 Login problems
- 📶 Network configuration
- ⚙️ Initial setup

Try asking:
- "How do I configure IP address?"
- "Connection failed"
- "How to sync offline data?"
- "Login not working"

Or describe your specific issue and I'll help!

---

📞 Need More Help?
If I couldn't answer your question, please contact:
👨‍💻 Developer:Anthony Capuyan
📱 Mobile:09359483634
📧 Email:anthony.capuyan23@gmail.com''';
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

  Widget _buildIpConfiguration() {
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
                Icons.computer,
                color: Color.fromRGBO(8, 111, 222, 0.977),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Server IP Address',
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
                  controller: _ipController,
                  decoration: InputDecoration(
                    hintText: 'e.g., 192.168.0.115',
                    labelText: 'IP Address',
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
                  final ip = _ipController.text.trim();
                  if (ip.isNotEmpty) {
                    await _saveCustomIp(ip);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('IP saved: $ip'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
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
          Text(
            'Current URL: $_currentBaseUrl',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontStyle: FontStyle.italic,
            ),
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
                  'Copy Full URL',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _copyToClipboard(_currentIp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Copy IP Only',
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
            '• IPv4 Address Not Showing: Use manual IP input (192.168.0.115)\n'
            '• NetworkInterface.list() Unsupported: Use retry button or manual input\n'
            '• API Connection Failed: Check XAMPP is running\n'
            '• Wrong IP Address: Update baseUrl in app_config.dart\n'
            '• No Offline Data: Login online and sync first\n'
            '• Can\'t Login Offline: Check credentials were stored\n'
            '• Sync Failed: Check user has assignments in database\n'
            '• Network Issues: Try different IP or check firewall\n'
            '• App Crashes: Clear app data and restart\n'
            '• IP Detection Issues: Use manual IP from ipconfig command',
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

}
