import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/app_config.dart';
import '../services/offline_sync_service.dart';
import '../services/hive_offline_database.dart';
import '../utils/network_utils.dart';

// Global instance for accessing chatbot from anywhere
class GlobalChatbotController {
  static final GlobalChatbotController _instance = GlobalChatbotController._internal();
  factory GlobalChatbotController() => _instance;
  GlobalChatbotController._internal();

  _DebugChatbotWidgetState? _state;

  void register(_DebugChatbotWidgetState state) {
    _state = state;
  }

  void toggle() {
    _state?.toggleChatbot();
  }

  Widget? getFloatingActionButton(BuildContext context) {
    return _state?.buildFloatingActionButton(context);
  }
}

class DebugChatbotWidget extends StatefulWidget {
  final VoidCallback? onClose;
  final bool isGlobal;

  const DebugChatbotWidget({
    super.key,
    this.onClose,
    this.isGlobal = false,
  });

  @override
  State<DebugChatbotWidget> createState() => _DebugChatbotWidgetState();
}

class _DebugChatbotWidgetState extends State<DebugChatbotWidget> {
  bool _isChatbotOpen = false;
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  
  // State variables that may be accessed from context
  String _localIp = 'Unknown';
  String _currentBaseUrl = '';
  String _currentIp = '';

  final List<String> _chatSuggestions = const [
    'App workflow',
    'How do I configure IP?',
    'Calculate 25 * 47',
    'Inspection features',
    'How to sync offline data?',
  ];

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isGlobal && mounted) {
      GlobalChatbotController().register(this);
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNetworkInfo() async {
    try {
      // Load current base URL
      final currentBaseUrl = await AppConfig.baseUrl;
      
      // Extract IP from current base URL
      String currentIp = '';
      if (currentBaseUrl.contains('http://')) {
        final parts = currentBaseUrl.split('http://')[1].split('/')[0];
        currentIp = parts;
      }

      // Try to get local IP (may fail if permissions not granted)
      String localIp = 'Unknown';
      try {
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          localIp = await NetworkUtils.getLocalIpAddress() ?? 'Unknown';
        } else if (!kIsWeb) {
          localIp = await NetworkUtils.getLocalIpAddress() ?? 'Unknown';
        }
      } catch (e) {
        localIp = 'Error: $e';
      }

      setState(() {
        _currentBaseUrl = currentBaseUrl;
        _currentIp = currentIp;
        _localIp = localIp;
      });
    } catch (e) {
      // Silently handle errors for global chatbot
    }
  }

  void toggleChatbot() {
    setState(() {
      _isChatbotOpen = !_isChatbotOpen;
      if (_isChatbotOpen && _chatMessages.isEmpty) {
        _chatMessages.add({
          'text': 'Hello! I am your Smart Assistant. I can help you with:\n\n• Math calculations\n• App features and workflows\n• Setup and configuration\n• Troubleshooting\n• Any questions about OBO Mobile\n\nWhat would you like to know?',
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      }
    });
    
    if (_isChatbotOpen) {
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
  }


  FloatingActionButton buildFloatingActionButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    
    return FloatingActionButton(
      onPressed: toggleChatbot,
      backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
      foregroundColor: Colors.white,
      child: Icon(
        Icons.psychology,
        size: isLargeTablet ? 32 : (isTablet ? 28 : 24),
      ),
    );
  }

  Widget? buildOverlay() {
    if (!_isChatbotOpen) return null;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final orientation = MediaQuery.of(context).orientation;
    
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
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
    
    return Material(
      type: MaterialType.transparency,
      child: Positioned.fill(
        child: Container(
          color: Colors.black54,
          child: SafeArea(
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(24),
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
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: headerPadding,
                      vertical: headerPadding * 0.9,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromRGBO(8, 111, 222, 0.98),
                          Color(0xFF1D4ED8),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 12 : 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.psychology_alt_rounded,
                            color: Colors.white,
                            size: headerIconSize,
                          ),
                        ),
                        SizedBox(width: isTablet ? 14 : 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Smart Assistant',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: headerFontSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ask me anything about the app, math questions, or get help!',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.82),
                                  fontSize: isTablet ? 13 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isChatbotOpen = false;
                            });
                            if (widget.onClose != null) {
                              widget.onClose!();
                            }
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: isTablet ? 26 : 22,
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
                  // Suggestions
                  if (_chatSuggestions.isNotEmpty)
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.symmetric(
                        horizontal: messagePadding,
                        vertical: isTablet ? 14 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                      ),
                      child: _buildChatSuggestions(
                        isTablet: isTablet,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                  // Messages
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFF8FAFC),
                            Colors.white,
                          ],
                        ),
                      ),
                      child: ListView.builder(
                        controller: _chatScrollController,
                        padding: EdgeInsets.all(messagePadding),
                        itemCount: _chatMessages.length,
                        itemBuilder: (context, index) {
                          final message = _chatMessages[index];
                          return _buildChatMessage(
                            message['text'] as String,
                            message['isUser'] as bool,
                            timestamp: message['timestamp'] as DateTime?,
                            isTablet: isTablet,
                            isSmallScreen: isSmallScreen,
                          );
                        },
                      ),
                    ),
                  ),
                  // Input area
                  Container(
                    padding: EdgeInsets.all(inputPadding),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: 'Ask anything - math, app features, troubleshooting...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: const BorderSide(color: Color.fromRGBO(8, 111, 222, 0.977), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 22 : 18,
                                vertical: isTablet ? 18 : (isSmallScreen ? 12 : 14),
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
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.fromRGBO(8, 111, 222, 0.977),
                                Color(0xFF1D4ED8),
                              ],
                            ),
                          ),
                          child: IconButton(
                            onPressed: () => _sendChatMessage(_chatController.text),
                            icon: Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: isTablet ? 24 : 20,
                            ),
                            padding: EdgeInsets.all(isTablet ? 12 : 10),
                            constraints: BoxConstraints(
                              minWidth: isTablet ? 50 : 42,
                              minHeight: isTablet ? 50 : 42,
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
        ),
      ),
    );
  }

  String _cleanMarkdown(String text) {
    // Remove all markdown formatting and create clean, formal text
    String cleaned = text;
    
    // Remove markdown bold (**text**) - iterate until all are removed
    while (cleaned.contains('**')) {
      final before = cleaned;
      cleaned = cleaned.replaceAllMapped(RegExp(r'\*\*([^*]+?)\*\*'), (match) => match.group(1) ?? '');
      if (cleaned == before) break; // No change made, avoid infinite loop
    }
    
    // Remove markdown bold (__text__)
    cleaned = cleaned.replaceAllMapped(RegExp(r'__([^_]+?)__'), (match) => match.group(1) ?? '');
    
    // Remove markdown italic (*text* or _text_) - but preserve math expressions
    // First handle italic with single asterisks (but not math multiplication)
    cleaned = cleaned.replaceAllMapped(RegExp(r'(?<![0-9a-zA-Z*])\*([^*\n\*]+?)\*(?![0-9a-zA-Z*])'), (match) => match.group(1) ?? '');
    cleaned = cleaned.replaceAllMapped(RegExp(r'(?<![0-9a-zA-Z_])_([^_\n_]+?)_(?![0-9a-zA-Z_])'), (match) => match.group(1) ?? '');
    
    // Remove any remaining double asterisks (shouldn't exist after above, but safety)
    cleaned = cleaned.replaceAll('**', '');
    
    // Remove markdown headers (# Header)
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    
    // Replace markdown horizontal rules
    cleaned = cleaned.replaceAll(RegExp(r'-{3,}'), '\n');
    
    // Remove backticks (but keep content)
    cleaned = cleaned.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    
    // Remove any remaining standalone asterisks that are clearly markdown (not math)
    // Only remove if asterisk is surrounded by spaces or at start/end of line
    cleaned = cleaned.replaceAllMapped(RegExp(r'(?:^|\s)\*(\s|$)', multiLine: true), (match) => match.group(1) ?? ' ');
    cleaned = cleaned.replaceAll(RegExp(r'^\*\s+', multiLine: true), ''); // Asterisk at start of line
    
    // Clean up excessive newlines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // Clean up multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'  +'), ' ');
    
    return cleaned.trim();
  }

  Widget _buildFormattedText(String text, double fontSize, bool isUser) {
    final cleanedText = _cleanMarkdown(text);
    
    return Text(
      cleanedText,
      style: TextStyle(
        color: isUser ? Colors.white : const Color(0xFF1F2937),
        fontSize: fontSize,
        height: 1.4,
      ),
    );
  }

  Widget _buildChatMessage(
    String text,
    bool isUser, {
    DateTime? timestamp,
    bool isTablet = false,
    bool isSmallScreen = false,
  }) {
    final iconSize = isTablet ? 24.0 : (isSmallScreen ? 18.0 : 20.0);
    final iconPadding = isTablet ? 10.0 : (isSmallScreen ? 6.0 : 8.0);
    final messagePadding = isTablet 
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
        : (isSmallScreen 
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12));
    final fontSize = isTablet ? 15.0 : (isSmallScreen ? 12.0 : 14.0);
    final spacing = isTablet ? 12.0 : (isSmallScreen ? 8.0 : 10.0);
    final timeLabel = timestamp != null
        ? '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
        : null;
    
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
                border: Border.all(
                  color: isUser
                      ? Colors.transparent
                      : const Color(0xFFE2E8F0),
                  width: isUser ? 0 : 1,
                ),
                boxShadow: isUser
                    ? const [
                        BoxShadow(
                          color: Color(0x22000000),
                          offset: Offset(0, 6),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: _buildFormattedText(text, fontSize, isUser),
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
          if (timeLabel != null)
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : spacing,
                right: isUser ? spacing : 0,
                top: 4,
              ),
              child: Text(
                timeLabel,
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: isTablet ? 11 : 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatSuggestions({required bool isTablet, required bool isSmallScreen}) {
    final chipStyle = TextStyle(
      fontSize: isTablet ? 13 : (isSmallScreen ? 11 : 12),
      fontWeight: FontWeight.w600,
    );

    return Wrap(
      spacing: isTablet ? 10 : 8,
      runSpacing: isTablet ? 8 : 6,
      children: _chatSuggestions.map((suggestion) {
        return ActionChip(
          label: Text(suggestion, style: chipStyle),
          backgroundColor: Colors.white,
          elevation: 0,
          pressElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFBFDBFE)),
          ),
          onPressed: () => _handleSuggestionTap(suggestion),
          avatar: const Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: Color.fromRGBO(8, 111, 222, 0.977),
          ),
        );
      }).toList(),
    );
  }

  void _sendChatMessage(String message) {
    if (message.trim().isEmpty) return;

    setState(() {
      _chatMessages.add({
        'text': message,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    final response = _processChatMessage(message);
    
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _chatMessages.add({
          'text': response,
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
      
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

  void _handleSuggestionTap(String suggestion) {
    _chatController.clear();
    _sendChatMessage(suggestion);
  }

  String _processChatMessage(String message) {
    final lowerMessage = message.toLowerCase();
    final trimmedMessage = message.trim();
    
    // MATH EVALUATION - Check if message contains math expression
    final mathResult = _evaluateMathExpression(trimmedMessage);
    if (mathResult != null) {
      return mathResult;
    }

    // IP Address issues
    if (lowerMessage.contains('ip') || lowerMessage.contains('address') || lowerMessage.contains('what is my ip')) {
      final hasValidIp = _localIp != 'Unknown' && 
                         _localIp != 'Loading...' && 
                         !_localIp.startsWith('Error:') && 
                         _localIp != 'No IPv4 address found';
      
      if (lowerMessage.contains('what') || lowerMessage.contains('my ip') || lowerMessage.contains('current ip')) {
        if (hasValidIp) {
          return '''Your Current IP Address

Mobile Device IP: $_localIp

Server Configuration:
• Current Server IP: ${_currentIp.isEmpty ? 'Not configured' : _currentIp}
• Current Base URL: $_currentBaseUrl

Next Steps:
1. Make sure your computer's IP matches the server IP above
2. Both devices should be on the same WiFi network
3. Test connection using "Test Connection" button

Tip: If server IP is different, update it in "Server Configuration" section above.''';
        } else {
          return '''IP Address Not Available

Status: $_localIp

Possible Reasons:
1. Not connected to WiFi network
2. Connected to wrong WiFi network
3. Mobile data is enabled instead of WiFi
4. Location permission denied (required on Android/iOS to read WiFi IP)

Solutions:

Option 1: Connect to Server WiFi
• Go to your device WiFi settings
• Connect to the same WiFi network as your server/computer
• Return to this app and refresh

Option 2: Manual IP Configuration
• Find your computer's IP address (run ipconfig in Command Prompt)
• Enter it in "Server IP Address" field
• Click "Save" button
• Test the connection

Option 3: Check Network Settings
• Make sure WiFi is enabled on your device
• Disable mobile data temporarily
• Ensure you're connected to the correct network

Option 4: Enable Location Permission
• When prompted, tap "Allow while using the app"
• Or go to Settings → Apps → OBO Mobile → Permissions → Allow Location
• Retry IP detection afterwards

Need Server Configuration Help? Ask me "server configuration" or "how to setup server" for detailed steps.''';
        }
      }
      
      if (lowerMessage.contains('not') || lowerMessage.contains('missing') || lowerMessage.contains('show')) {
        if (!hasValidIp) {
          return '''IP Address Not Showing

Current Status: $_localIp

Quick Fixes:

0. Allow Location Access
   • Location permission is required to read the WiFi IP on Android/iOS
   • When prompted, tap "Allow while using the app"
   • You can also enable it from Settings → Apps → OBO Mobile → Permissions

1. Connect to Server WiFi
   • Open device WiFi settings
   • Connect to the same network as your server
   • Return here and refresh

2. Manual IP Input
   • Get your computer's IP (run ipconfig)
   • Enter it in "Server IP Address" field
   • Click "Save"

3. Check Network Connection
   • Ensure WiFi is enabled
   • Disable mobile data
   • Verify correct network

Not connected to WiFi? You need to connect to the server's WiFi network first! Ask me "server configuration" for setup help.''';
        }
        return '''IP Address Not Showing

Here is how to fix it:
1. Make sure the app has Location permission (required for WiFi IP on Android/iOS)
2. Click "Retry IP Detection" button
3. If it still does not work, use manual IP input:
   • Enter your computer's IP (e.g., 192.168.x.x)
   • Click "Set Manual" button
   • You can find your IP by running ipconfig in Command Prompt

Tip: Make sure your mobile device and computer are on the same WiFi network!''';
      }
      
      if (hasValidIp) {
        return '''IP Address Information

Your Mobile IP: $_localIp
Server IP: ${_currentIp.isEmpty ? 'Not configured' : _currentIp}
Base URL: $_currentBaseUrl

To configure server IP:
1. Find your computer's IP (run ipconfig in Command Prompt)
2. Enter it in "Server IP Address" field
3. Click "Save" button
4. Test connection

Need help? Ask me:
• "What is my IP?" - See your current IP
• "Server configuration" - Setup guide
• "Connection failed" - Troubleshooting''';
      } else {
        return '''IP Address Help

Current Status: $_localIp

You need to:
1. Connect to Server WiFi
   • Go to WiFi settings
   • Connect to the same network as your server
   • This is required for IP detection

2. Or Configure Manually
   • Get server IP from computer (ipconfig)
   • Enter in "Server IP Address" field
   • Click "Save"

Not connected to WiFi? You must connect to the server's WiFi network first!

Ask me "server configuration" for complete setup guide.''';
      }
    }

    // Connection issues
    if (lowerMessage.contains('connect') || lowerMessage.contains('server') || lowerMessage.contains('unreachable')) {
      if (lowerMessage.contains('fail') || lowerMessage.contains('error') || lowerMessage.contains('not reachable')) {
        return '''Connection Failed

Let us troubleshoot step by step:

1. Check XAMPP is running
   • Make sure Apache is started in XAMPP Control Panel

2. Verify IP Address
   • Check if the IP address is correct
   • Both devices must be on the same network

3. Test Connection
   • Click "Test Connection" button
   • Check the error message for details

4. Firewall Check
   • Make sure Windows Firewall allows Apache
   • Check if port 80 is not blocked

5. Manual IP Method
   • Use the manual IP input if auto-detection fails

Still having issues? Try restarting XAMPP!''';
      }
      return '''Connection Setup

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
        return '''No Offline Data

To sync data for offline use:

1. First Login Online
   • Connect to WiFi/server network
   • Login with your credentials

2. Sync Your Data
   • Go to Dashboard
   • Click "Sync My Data" button
   • Wait for sync to complete

3. Test Offline
   • Turn off WiFi/internet
   • Logout and login again
   • You should be able to access your data offline

Important: You must sync while online first!''';
      }
      return '''Offline Data and Sync

The app supports offline mode:
• Login online first
• Sync your data in dashboard
• Then you can use offline

Having sync issues? Let me know!''';
    }

    // Login issues
    if (lowerMessage.contains('login') || lowerMessage.contains('sign in') || lowerMessage.contains('credential')) {
      if (lowerMessage.contains('fail') || lowerMessage.contains('error') || lowerMessage.contains('cannot')) {
        return '''Login Issues

Troubleshooting steps:

1. Online Login Failed
   • Check server connection (use Test Connection)
   • Verify XAMPP is running
   • Check if IP address is correct

2. Offline Login Failed
   • Make sure you synced data while online
   • Check if credentials were stored
   • Try syncing again from dashboard

3. Server Unreachable
   • Use WiFi connected to server network
   • Or sync data first, then use offline mode

Tip: If server is unreachable, the app will automatically try offline login if you have synced data.''';
      }
      return '''Login Help

You can login:
• Online: When connected to server
• Offline: After syncing data online first

Need help with a specific login issue?''';
    }

    // Network issues
    if (lowerMessage.contains('network') || lowerMessage.contains('wifi') || lowerMessage.contains('internet')) {
      return '''Network Setup

Network requirements:
1. Both devices on same WiFi - Mobile and computer must be on same network
2. XAMPP running - Apache server must be active
3. Correct IP - Use your computer's local IP address
4. Firewall - Windows Firewall should allow Apache

Common Issues:
• Cannot detect IP → Use manual IP input
• Wrong network → Connect both devices to same WiFi
• Firewall blocking → Allow Apache in Windows Firewall

Need help with a specific network issue?''';
    }

    if (lowerMessage.contains('workflow') || lowerMessage.contains('flow') || lowerMessage.contains('process')) {
      return '''OBO Mobile App Workflow

1. Login
   • Connect your device to the same Wi-Fi network as the OBO server (XAMPP)
   • Login online to verify credentials and load permissions

2. Sync Assignments and Data
   • On the dashboard, tap "Sync My Data" to pull assignments, references, and checklists
   • Syncing stores everything securely in Hive for offline use

3. Inspection Workflow
   • Scan a business QR code to start or resume an inspection
   • Complete sections, capture photos/videos, add remarks, and track status (in_progress / passed / not_passed)
   • Save progress at any time; unsynced records stay marked as Pending

4. Operate Offline
   • After syncing, you can disconnect from Wi-Fi
   • The app works offline using stored inspections and credentials

5. Export and Submit
   • When back online, go to Inspection Reports
   • Use Export to upload new or updated inspections to the server
   • If the server copy is missing, the app automatically recreates it; repeated exports update existing records

6. Backups
   • From Inspection Reports → Transactions, tap Create Excel Backup to export every inspection to an .xlsx file
   • Mobile/Desktop: saved locally in app documents (works offline)
   • Web: triggers an immediate browser download

7. Debug and Network
   • Visit the Debug Screen to inspect IPs, server status, offline data, and run health checks
   • The built-in assistant here can guide you through setup, syncing, and troubleshooting

Need a visual checklist or help with a specific step? Just ask!''';
    }

    // Setup/Installation
    if (lowerMessage.contains('setup') || lowerMessage.contains('install') || lowerMessage.contains('config') || lowerMessage.contains('configure')) {
      return '''Setup Guide

Initial Setup Steps:

1. Install XAMPP
   • Download and install XAMPP
   • Start Apache service

2. Configure IP Address
   • Find your computer's IP (run ipconfig)
   • Enter it in Server IP Address field
   • Click Save

3. Test Connection
   • Click "Test Connection" button
   • Should show "API server is reachable"

4. First Login
   • Login with your credentials
   • Sync data from dashboard

5. Test Offline Mode
   • Turn off WiFi
   • Login again (should work offline)

Need help with a specific step?''';
    }

    // API issues
    if (lowerMessage.contains('api') || lowerMessage.contains('endpoint')) {
      return '''API Troubleshooting

API Connection Issues:

1. Check Server Status
   • Verify XAMPP Apache is running
   • Check if server responds

2. Test Connection
   • Use "Test Connection" button
   • Check latency and status

3. Verify URL
   • URL format: http://[IP]/OBO-LGU/api
   • Make sure IP is correct
   • Check URL is accessible

4. Common Errors
   • "No host specified" → Check IP configuration
   • "Connection timeout" → Check firewall/network
   • "404 Not Found" → Check API path

Need help with a specific API error?''';
    }

    // Inspection Features
    if (lowerMessage.contains('inspection') || lowerMessage.contains('section') || lowerMessage.contains('form')) {
      if (lowerMessage.contains('section') || lowerMessage.contains('sections')) {
        return '''📋 **Inspection Sections**

The OBO Mobile app has **7 main inspection sections**:

1. **🏗️ Architectural**
   - Evaluate building design and structure
   - Add remarks and assessment
   - Set status: In Progress / Passed / Not Passed

2. **📐 Line Grade**
   - Check alignment and grading
   - Add photos and videos
   - Track completion status

3. **🏛️ Civil Structural**
   - Assess structural integrity
   - Document findings with media
   - Record status changes

4. **🚰 Sanitary Plumbing**
   - Inspect plumbing systems
   - Add detailed remarks
   - Track compliance

5. **⚡ Electrical Electronics**
   - Check electrical systems
   - Document with photos/videos
   - Record assessment results

6. **🔧 Mechanical**
   - Inspect mechanical systems
   - Add detailed assessments
   - Track status

**Each section supports:**
- 📸 Photos (multiple per section)
- 🎥 Videos
- 📝 Detailed remarks
- ✅ Status tracking
- 📍 Location data (GPS)

**To start an inspection:**
1. Scan a business QR code
2. Complete each section
3. Add media and remarks
4. Set status for each section
5. Save and sync when online

Need help with a specific section?''';
      }
      if (lowerMessage.contains('photo') || lowerMessage.contains('image') || lowerMessage.contains('picture') || lowerMessage.contains('camera')) {
        return '''📸 **Adding Photos to Inspections**

**How to add photos:**
1. Open an inspection form
2. Navigate to any section (Architectural, Mechanical, etc.)
3. Tap the **Camera icon** or **"Add Photo"** button
4. Take a new photo or select from gallery
5. Photo is automatically saved to that section

**Features:**
- ✅ Multiple photos per section
- ✅ Photos stored locally (offline support)
- ✅ Photos sync when you sync inspection
- ✅ Photos included in reports

**Tip:** You can add photos at any time during inspection. They're organized by section!''';
      }
      if (lowerMessage.contains('video') || lowerMessage.contains('record')) {
        return '''🎥 **Adding Videos to Inspections**

**How to add videos:**
1. Open an inspection form
2. Go to any inspection section
3. Tap the **Video icon** or **"Add Video"** button
4. Record a new video or select from gallery
5. Video is saved to that section

**Features:**
- ✅ Multiple videos per section
- ✅ Videos stored locally
- ✅ Videos sync when inspection syncs
- ✅ Videos included in reports

**Note:** Videos may take longer to sync due to file size.''';
      }
      if (lowerMessage.contains('status') || lowerMessage.contains('passed') || lowerMessage.contains('failed')) {
        return '''✅ **Inspection Status**

Each inspection section has **3 status options**:

1. **🟡 In Progress**
   - Section is being worked on
   - Not yet completed
   - Default status when started

2. **🟢 Passed**
   - Section meets requirements
   - Inspection criteria satisfied
   - Mark when section is approved

3. **🔴 Not Passed**
   - Section doesn't meet requirements
   - Issues found that need attention
   - Mark when problems are identified

**How to change status:**
1. Open inspection form
2. Scroll to the section
3. Find status dropdown/selector
4. Select new status
5. Save inspection

**Tip:** Status changes are tracked in inspection history!''';
      }
      return '''📋 **Inspection Features**

**Key Features:**
- 🏗️ 7 inspection sections (Architectural, Mechanical, Civil Structural, etc.)
- 📸 Add multiple photos per section
- 🎥 Add videos to sections
- 📝 Detailed remarks for each section
- ✅ Status tracking (In Progress / Passed / Not Passed)
- 📍 GPS location capture
- 💾 Offline support (save without internet)
- 🔄 Auto-sync when online

**Workflow:**
1. Scan QR code → Start inspection
2. Complete sections → Add photos/videos/remarks
3. Set status → Track progress
4. Save → Stored locally
5. Sync → Upload to server

**Ask me about:**
- "What are the inspection sections?"
- "How to add photos?"
- "How to change status?"
- "Inspection workflow"

Need help with a specific inspection feature?''';
    }

    // Reports & Export
    if (lowerMessage.contains('report') || lowerMessage.contains('export') || lowerMessage.contains('backup') || lowerMessage.contains('excel')) {
      if (lowerMessage.contains('export')) {
        return '''📤 **Exporting Inspections**

**How to export:**
1. Go to **Inspection Reports** screen
2. Find the inspection you want to export
3. Tap the inspection card
4. Click **"Export"** or **"Sync"** button
5. Inspection uploads to server

**Export Features:**
- ✅ Uploads to server when online
- ✅ Automatically syncs photos/videos
- ✅ Updates existing records if already on server
- ✅ Creates new record if not on server
- ✅ Marks as "Synced" after successful export

**Offline Export:**
- Inspections saved locally
- Auto-export when you go online
- Manual export available anytime

**Note:** Make sure you're connected to the server to export!''';
      }
      if (lowerMessage.contains('backup') || lowerMessage.contains('excel')) {
        return '''📊 **Creating Excel Backup**

**How to create backup:**
1. Go to **Inspection Reports** screen
2. Tap **"Transactions"** or menu
3. Click **"Create Excel Backup"**
4. File is saved/downloaded

**Backup Features:**
- ✅ Exports ALL inspections
- ✅ Includes all inspection data
- ✅ Works offline
- ✅ Mobile/Desktop: Saved locally in app documents
- ✅ Web: Downloads immediately

**File Location (Mobile):**
- Saved in app documents folder
- Accessible via file manager
- Can be shared/transferred

**Tip:** Create regular backups to keep your data safe!''';
      }
      return '''📊 **Reports & Export**

**Available Features:**

1. **📤 Export Inspections**
   - Upload inspections to server
   - Sync photos and videos
   - Update existing records

2. **📊 Excel Backup**
   - Export all inspections to .xlsx
   - Works offline
   - Includes complete data

3. **📋 Inspection Reports Screen**
   - View all inspections
   - Filter by status
   - Search by business ID
   - See sync status

4. **🗑️ Trash/Restore**
   - Deleted inspections go to trash
   - Restore if needed
   - Permanent deletion available

**Ask me about:**
- "How to export?"
- "How to create backup?"
- "View reports"

Need help with reports?''';
    }

    // Trash & Restore
    if (lowerMessage.contains('trash') || lowerMessage.contains('delete') || lowerMessage.contains('restore') || lowerMessage.contains('deleted')) {
      return '''🗑️ **Trash & Restore System**

**Trash Features:**
- ✅ Deleted inspections go to trash (not permanently deleted)
- ✅ View all deleted inspections
- ✅ Restore inspections if needed
- ✅ Permanently delete from trash
- ✅ Secure file deletion (overwrites files)

**How to use:**

**1. Delete Inspection:**
   - Go to Inspection Reports
   - Tap inspection card
   - Click "Move to Trash" button
   - Inspection moved to trash

**2. View Trash:**
   - Tap trash icon in Reports header
   - Or go to Profile → Trash
   - See all deleted inspections

**3. Restore Inspection:**
   - Open trash
   - Find inspection
   - Tap "Restore" button
   - Inspection restored to Reports

**4. Permanently Delete:**
   - Open trash
   - Tap "Permanently Delete"
   - Files securely deleted (cannot restore)

**Security:**
- Secure deletion overwrites files multiple times
- Media files also securely deleted
- Cannot recover after permanent deletion

**Tip:** Always check trash before permanently deleting!''';
    }

    // History
    if (lowerMessage.contains('history') || lowerMessage.contains('log') || lowerMessage.contains('audit')) {
      return '''📜 **Inspection History**

**History Features:**
- ✅ Detailed log of all inspection changes
- ✅ Track who made changes
- ✅ See what changed and when
- ✅ View status changes
- ✅ Track media additions
- ✅ Monitor sync events

**How to view history:**
1. Go to **Inspection Reports**
2. Find the inspection
3. Tap **"History"** button (clock icon)
4. View detailed history log

**What's logged:**
- ✅ Inspection creation
- ✅ Field updates
- ✅ Status changes
- ✅ Photo/video additions
- ✅ Sync events
- ✅ User information
- ✅ Timestamps

**History includes:**
- Action type (created, updated, status_changed, etc.)
- User who made the change
- Timestamp
- Description of changes
- Old and new values

**Tip:** History helps track all inspection activities!''';
    }

    // Accessibility
    if (lowerMessage.contains('accessibility') || lowerMessage.contains('font') || lowerMessage.contains('contrast') || lowerMessage.contains('size') || lowerMessage.contains('text size')) {
      return '''♿ **Accessibility Features**

**Available Settings:**

1. **🔤 Font Size Adjustment**
   - Adjust text size (80% - 200%)
   - Applies to all screens
   - Helps with readability
   - Access via Profile → Accessibility

2. **🔲 High Contrast Mode**
   - Enhanced contrast for better visibility
   - Helps visually impaired users
   - Toggle on/off
   - Access via Profile → Accessibility

**How to access:**
1. Go to **Profile** screen
2. Tap **"Accessibility"** option
3. Adjust font size slider
4. Toggle high contrast mode
5. Changes apply immediately

**Features:**
- ✅ Real-time preview
- ✅ Settings saved automatically
- ✅ Applies across entire app
- ✅ Works offline

**Tip:** Adjust settings to your comfort level!''';
    }

    // Tutorial/Onboarding
    if (lowerMessage.contains('tutorial') || lowerMessage.contains('onboarding') || lowerMessage.contains('guide') || lowerMessage.contains('walkthrough')) {
      return '''📚 **Tutorial & Onboarding**

**Interactive Tutorial:**
- ✅ 5-step walkthrough
- ✅ Swipeable pages
- ✅ Visual guides with animations
- ✅ Skip option available

**How to access:**
1. **First Time:** Shows automatically on first launch
2. **Manual:** Go to Profile → Tutorial
3. **Reset:** Profile → Reset Tutorial (for testing)

**Tutorial covers:**
1. Welcome & Overview
2. QR Code Scanning
3. Completing Inspections
4. Sync & Reports
5. Get Started

**Features:**
- 📱 Responsive design
- 🎨 Beautiful animations
- ⏭️ Skip anytime
- 🔄 Can view again anytime

**To view again:**
- Go to Profile screen
- Tap "Tutorial" option
- Review the guide

**Tip:** Tutorial helps new users get started quickly!''';
    }

    // Lazy Loading
    if (lowerMessage.contains('lazy') || lowerMessage.contains('load') || lowerMessage.contains('performance') || lowerMessage.contains('slow')) {
      return '''⚡ **Performance & Lazy Loading**

**Performance Features:**

1. **📄 Lazy Loading**
   - Loads inspections in batches (20 per page)
   - Faster initial load
   - Better performance with many inspections
   - "Load More" button to load more items

2. **💾 Offline Storage**
   - All data stored locally (Hive database)
   - Fast access without internet
   - Efficient data management

3. **🔄 Smart Syncing**
   - Only syncs when online
   - Batches updates
   - Reduces data usage

**How lazy loading works:**
- Initially loads first 20 inspections
- Scroll to bottom or tap "Load More"
- Loads next batch automatically
- Continues until all loaded

**Benefits:**
- ✅ Faster app startup
- ✅ Smoother scrolling
- ✅ Less memory usage
- ✅ Better user experience

**Tip:** Lazy loading helps when you have many inspections!''';
    }

    // General help
    if (lowerMessage.contains('help') || lowerMessage.contains('how') || lowerMessage.contains('what')) {
      return '''🤖 **Smart Assistant Help**

I can help you with:

🔢 **Math & Calculations:**
- Basic math (+, -, *, /)
- Advanced (sqrt, sin, cos, tan, log, ln)
- Power operations (^)
- Constants (pi, e)

📱 **App Features:**
- Inspection sections & workflow
- Adding photos/videos
- Status management
- Reports & exports
- Trash & restore
- History tracking
- Accessibility settings

⚙️ **Setup & Configuration:**
- IP address setup
- Connection issues
- Offline data & sync
- Login problems
- Network configuration

**Just ask me:**
- "Calculate 25 * 47"
- "What are the inspection sections?"
- "How do I configure IP?"
- "Connection failed"
- "How to add photos?"
- "Inspection workflow"

Or describe your specific question!''';
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

    // QR Code & Scanning
    if (lowerMessage.contains('qr') || lowerMessage.contains('scan') || lowerMessage.contains('code')) {
      return '''📷 **QR Code Scanning**

**How to scan QR code:**
1. Tap the **QR Scanner** button on dashboard
2. Point camera at QR code
3. Code is automatically scanned
4. Start new inspection or resume existing

**QR Code Features:**
- ✅ Quick business identification
- ✅ Automatic inspection lookup
- ✅ Resume existing inspections
- ✅ Start new inspections
- ✅ Works offline (scanned data stored)

**What happens after scan:**
- If inspection exists → Opens that inspection
- If new business → Starts new inspection
- Business ID stored for reference
- Can add multiple inspections per business

**Tip:** QR codes should contain business identification data!''';
    }

    // Dashboard
    if (lowerMessage.contains('dashboard') || lowerMessage.contains('home') || lowerMessage.contains('main')) {
      return '''🏠 **Dashboard**

**Dashboard Features:**
- ✅ Quick access to all features
- ✅ Sync My Data button
- ✅ QR Scanner access
- ✅ Navigation to all screens
- ✅ Inspection Reports link
- ✅ Profile & Settings

**Main Functions:**
1. **Sync My Data** - Pull assignments and data from server
2. **QR Scanner** - Scan business QR codes
3. **Inspection Reports** - View all inspections
4. **Profile** - Settings and account info

**Dashboard Workflow:**
1. Login → Dashboard appears
2. Sync data → Get assignments
3. Scan QR → Start inspection
4. Complete work → View reports

Need help with dashboard features?''';
    }

    // Profile & Settings
    if (lowerMessage.contains('profile') || lowerMessage.contains('setting') || lowerMessage.contains('account')) {
      return '''👤 **Profile & Settings**

**Profile Features:**
- ✅ View user information
- ✅ Access settings
- ✅ Tutorial/Onboarding
- ✅ Accessibility settings
- ✅ Trash management
- ✅ Logout option

**Settings Available:**
1. **Tutorial** - View app guide
2. **Accessibility** - Font size & contrast
3. **Trash** - Manage deleted items
4. **Reset Tutorial** - For testing

**How to access:**
- Tap profile icon/avatar
- Or go to menu → Profile
- Access all settings from there

Need help with specific settings?''';
    }

    // Default response
    return '''🤔 **I'm here to help!**

I'm your **Smart Assistant** and I can help with:

🔢 **Math Calculations:**
- Basic: "25 * 47" or "125 / 5"
- Advanced: "sqrt(144)" or "sin(30)"
- Power: "2^8" or "5^3"
- Constants: "pi" or "e"

📱 **App Features:**
- Inspection sections & workflow
- Adding photos/videos
- Status management
- Reports & exports
- Trash & restore
- History tracking
- QR scanning
- Dashboard functions

⚙️ **Setup & Troubleshooting:**
- IP address configuration
- Connection issues
- Offline data & sync
- Login problems
- Network setup

💡 **Try asking:**
- "Calculate 125 * 87"
- "What are the inspection sections?"
- "How do I configure IP?"
- "How to add photos?"
- "Connection failed"
- "Inspection workflow"

Or describe your specific question and I'll help!

---

📞 Need More Help?
Contact developer:
👨‍💻 Anthony Capuyan
📱 09359483634
📧 anthony.capuyan23@gmail.com''';
  }

  /// Evaluates mathematical expressions safely
  String? _evaluateMathExpression(String message) {
    try {
      // Remove common math question prefixes
      String expression = message
          .replaceAll(RegExp(r"^(calculate|compute|solve|what is|what's|equals?|=\s*)", caseSensitive: false), '')
          .replaceAll(RegExp(r'\?$'), '')
          .trim();
      
      // Check if it looks like a math expression
      final hasMathOps = RegExp(r'[\+\-\*\/\^\(\)]|sqrt|sin|cos|tan|log|ln|pi|e|%').hasMatch(expression);
      final hasNumbers = RegExp(r'\d').hasMatch(expression);
      
      if (!hasMathOps || !hasNumbers) {
        return null; // Not a math question
      }
      
      // Normalize operators
      expression = expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll(RegExp(r'\s+'), ''); // Remove spaces
      
      // Replace 'x' with '*' only when it's clearly multiplication (between numbers or after closing paren)
      expression = expression.replaceAllMapped(
        RegExp(r'([\d\)])\s*x\s*([\d\(])', caseSensitive: false),
        (match) => '${match.group(1)}*${match.group(2)}',
      );
      
      // Handle special constants
      expression = expression.replaceAll(RegExp(r'\bpi\b', caseSensitive: false), math.pi.toString());
      expression = expression.replaceAll(RegExp(r'\be\b(?![0-9])', caseSensitive: false), math.e.toString());
      
      // Handle percentage
      if (expression.contains('%')) {
        final percentMatch = RegExp(r'(\d+\.?\d*)\s*%').firstMatch(expression);
        if (percentMatch != null) {
          final percent = double.parse(percentMatch.group(1)!);
          expression = expression.replaceAll(percentMatch.group(0)!, (percent / 100).toString());
        }
      }
      
      // Handle sqrt
      expression = expression.replaceAllMapped(
        RegExp(r'sqrt\(([^)]+)\)', caseSensitive: false),
        (match) {
          try {
            final value = double.parse(match.group(1)!);
            return math.sqrt(value).toString();
          } catch (e) {
            return match.group(0)!;
          }
        },
      );
      
      // Handle power (^)
      expression = _evaluatePower(expression);
      
      // Handle trigonometric functions
      expression = expression.replaceAllMapped(
        RegExp(r'sin\(([^)]+)\)', caseSensitive: false),
        (match) {
          try {
            final value = double.parse(match.group(1)!);
            return math.sin(value).toString();
          } catch (e) {
            return match.group(0)!;
          }
        },
      );
      expression = expression.replaceAllMapped(
        RegExp(r'cos\(([^)]+)\)', caseSensitive: false),
        (match) {
          try {
            final value = double.parse(match.group(1)!);
            return math.cos(value).toString();
          } catch (e) {
            return match.group(0)!;
          }
        },
      );
      expression = expression.replaceAllMapped(
        RegExp(r'tan\(([^)]+)\)', caseSensitive: false),
        (match) {
          try {
            final value = double.parse(match.group(1)!);
            return math.tan(value).toString();
          } catch (e) {
            return match.group(0)!;
          }
        },
      );
      
      // Handle logarithms
      expression = expression.replaceAllMapped(
        RegExp(r'log\(([^)]+)\)', caseSensitive: false),
        (match) {
          try {
            final value = double.parse(match.group(1)!);
            if (value > 0) {
              return (math.log(value) / math.ln10).toString();
            }
          } catch (e) {}
          return match.group(0)!;
        },
      );
      expression = expression.replaceAllMapped(
        RegExp(r'ln\(([^)]+)\)', caseSensitive: false),
        (match) {
          try {
            final value = double.parse(match.group(1)!);
            if (value > 0) {
              return math.log(value).toString();
            }
          } catch (e) {}
          return match.group(0)!;
        },
      );
      
      // Handle parentheses recursively
      while (expression.contains('(')) {
        final parenMatch = RegExp(r'\(([^()]+)\)').firstMatch(expression);
        if (parenMatch == null) break;
        
        final innerExpr = parenMatch.group(1)!;
        final innerResult = _evaluateSimpleExpression(innerExpr);
        expression = expression.replaceAll(parenMatch.group(0)!, innerResult);
      }
      
      // Evaluate final expression
      final result = _evaluateSimpleExpression(expression);
      final resultNum = double.tryParse(result);
      
      if (resultNum == null) {
        return null;
      }
      
      // Format result
      String formattedResult;
      if (resultNum.isInfinite || resultNum.isNaN) {
        return 'Math Error\n\nThe expression results in an invalid value (Infinity or NaN).\n\nPlease check your calculation!';
      } else if (resultNum.abs() > 1000000 || (resultNum.abs() < 0.000001 && resultNum != 0)) {
        formattedResult = resultNum.toStringAsExponential(6);
      } else {
        // Remove trailing zeros
        formattedResult = resultNum.toStringAsFixed(10).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
        if (formattedResult.isEmpty) formattedResult = '0';
      }
      
      return '''Math Result

Expression: $message

Answer: $formattedResult

Tips:
• Use * for multiplication
• Use / for division  
• Use ^ for power
• Use sqrt() for square root
• Use sin(), cos(), tan() for trigonometry
• Use log() or ln() for logarithms
• Use pi or e for constants''';
      
    } catch (e) {
      // Not a valid math expression or error occurred
      return null;
    }
  }
  
  String _evaluatePower(String expr) {
    // Handle power operations (^)
    while (expr.contains('^')) {
      final powerMatch = RegExp(r'([\d\.]+)\s*\^\s*([\d\.]+)').firstMatch(expr);
      if (powerMatch == null) break;
      
      try {
        final base = double.parse(powerMatch.group(1)!);
        final exp = double.parse(powerMatch.group(2)!);
        final result = math.pow(base, exp).toDouble();
        expr = expr.replaceAll(powerMatch.group(0)!, result.toString());
      } catch (e) {
        break;
      }
    }
    return expr;
  }
  
  String _evaluateSimpleExpression(String expr) {
    try {
      // Remove any remaining spaces
      expr = expr.replaceAll(RegExp(r'\s+'), '');
      
      // Handle division first (left to right)
      while (expr.contains('/')) {
        final divMatch = RegExp(r'([\d\.\-]+)\s*/\s*([\d\.\-]+)').firstMatch(expr);
        if (divMatch == null) break;
        
        final num1 = double.parse(divMatch.group(1)!);
        final num2 = double.parse(divMatch.group(2)!);
        if (num2 == 0) {
          throw Exception('Division by zero');
        }
        final result = (num1 / num2).toString();
        expr = expr.replaceAll(divMatch.group(0)!, result);
      }
      
      // Handle multiplication (left to right)
      while (expr.contains('*')) {
        final mulMatch = RegExp(r'([\d\.\-]+)\s*\*\s*([\d\.\-]+)').firstMatch(expr);
        if (mulMatch == null) break;
        
        final num1 = double.parse(mulMatch.group(1)!);
        final num2 = double.parse(mulMatch.group(2)!);
        final result = (num1 * num2).toString();
        expr = expr.replaceAll(mulMatch.group(0)!, result);
      }
      
      // Handle subtraction and addition (left to right)
      // First handle subtraction
      while (RegExp(r'[\d\.]+\s*-\s*[\d\.]+').hasMatch(expr)) {
        final subMatch = RegExp(r'([\d\.]+)\s*-\s*([\d\.]+)').firstMatch(expr);
        if (subMatch == null) break;
        
        final num1 = double.parse(subMatch.group(1)!);
        final num2 = double.parse(subMatch.group(2)!);
        final result = (num1 - num2).toString();
        expr = expr.replaceAll(subMatch.group(0)!, result);
      }
      
      // Then handle addition
      while (expr.contains('+') && !expr.startsWith('+')) {
        final addMatch = RegExp(r'([\d\.\-]+)\s*\+\s*([\d\.\-]+)').firstMatch(expr);
        if (addMatch == null) break;
        
        final num1 = double.parse(addMatch.group(1)!);
        final num2 = double.parse(addMatch.group(2)!);
        final result = (num1 + num2).toString();
        expr = expr.replaceAll(addMatch.group(0)!, result);
      }
      
      return expr;
    } catch (e) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGlobal) {
      // When global, build overlay if open
      final overlay = buildOverlay();
      if (overlay != null) {
        return overlay;
      }
    }
    return const SizedBox.shrink();
  }
}

