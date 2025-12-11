import 'package:flutter/material.dart';
import 'debug_chatbot_widget.dart';

class AppWithChatbot extends StatelessWidget {
  final Widget child;

  const AppWithChatbot({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Builder(
          builder: (context) {
            return DebugChatbotWidget(
              isGlobal: true,
            );
          },
        ),
      ],
    );
  }
}

