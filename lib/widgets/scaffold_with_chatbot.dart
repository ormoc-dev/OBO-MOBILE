import 'package:flutter/material.dart';
import 'debug_chatbot_widget.dart';

/// A Scaffold wrapper that automatically includes the chatbot floating action button
class ScaffoldWithChatbot extends StatelessWidget {
  final Widget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;

  const ScaffoldWithChatbot({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.bottomNavigationBar,
    this.bottomSheet,
  });

  @override
  Widget build(BuildContext context) {
    // Get chatbot FAB if available
    final chatbotFab = GlobalChatbotController().getFloatingActionButton(context);

    // If there's a custom FAB and chatbot FAB, use Stack to show both
    if (floatingActionButton != null && chatbotFab != null) {
      return Scaffold(
        appBar: appBar as PreferredSizeWidget?,
        body: body,
        drawer: drawer,
        endDrawer: endDrawer,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        bottomNavigationBar: bottomNavigationBar,
        bottomSheet: bottomSheet,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation ?? FloatingActionButtonLocation.endFloat,
      );
    }

    // Use chatbot FAB if no custom FAB is provided
    return Scaffold(
      appBar: appBar as PreferredSizeWidget?,
      body: body,
      drawer: drawer,
      endDrawer: endDrawer,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      floatingActionButton: chatbotFab ?? floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation ?? FloatingActionButtonLocation.endFloat,
    );
  }
}



