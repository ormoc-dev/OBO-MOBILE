import 'package:flutter/material.dart';
import 'debug_chatbot_widget.dart';

class GlobalChatbotProvider extends InheritedWidget {
  final GlobalKey<_GlobalChatbotState> chatbotKey;

  const GlobalChatbotProvider({
    super.key,
    required this.chatbotKey,
    required super.child,
  });

  static GlobalChatbotProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlobalChatbotProvider>();
  }

  @override
  bool updateShouldNotify(GlobalChatbotProvider oldWidget) {
    return chatbotKey != oldWidget.chatbotKey;
  }
}

class GlobalChatbot extends StatefulWidget {
  final Widget child;

  const GlobalChatbot({
    super.key,
    required this.child,
  });

  @override
  State<GlobalChatbot> createState() => _GlobalChatbotState();
}

class _GlobalChatbotState extends State<GlobalChatbot> {
  final GlobalKey<_GlobalChatbotState> _key = GlobalKey<_GlobalChatbotState>();
  final GlobalKey<DebugChatbotWidgetState> _chatbotKey = GlobalKey<DebugChatbotWidgetState>();

  void toggleChatbot() {
    _chatbotKey.currentState?.toggleChatbot();
  }

  FloatingActionButton? getFloatingActionButton() {
    return _chatbotKey.currentState?.buildFloatingActionButton();
  }

  Widget? getOverlay() {
    return _chatbotKey.currentState?.buildOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return GlobalChatbotProvider(
      chatbotKey: _key,
      child: Stack(
        children: [
          widget.child,
          DebugChatbotWidget(
            key: _chatbotKey,
            isGlobal: true,
          ),
        ],
      ),
    );
  }
}

// Extension to expose chatbot methods
extension GlobalChatbotExtension on BuildContext {
  void toggleChatbot() {
    final provider = GlobalChatbotProvider.of(this);
    // The chatbot is in the widget tree, we'll access it through the Stack
  }
}



