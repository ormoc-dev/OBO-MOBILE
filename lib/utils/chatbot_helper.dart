import 'package:flutter/material.dart';
import '../widgets/debug_chatbot_widget.dart';

/// Extension to easily add chatbot FAB to any Scaffold
extension ChatbotExtension on BuildContext {
  /// Returns the chatbot floating action button if available
  Widget? getChatbotFab() {
    return GlobalChatbotController().getFloatingActionButton(this);
  }

  /// Toggles the chatbot overlay
  void toggleChatbot() {
    GlobalChatbotController().toggle();
  }
}

