import 'package:flutter/material.dart';
import '../services/accessibility_service.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  bool _highContrast = false;
  double _fontScale = 1.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final highContrast = await AccessibilityService.isHighContrastEnabled();
    final fontScale = await AccessibilityService.getFontScale();

    setState(() {
      _highContrast = highContrast;
      _fontScale = fontScale;
      _isLoading = false;
    });
  }

  Future<void> _updateHighContrast(bool value) async {
    setState(() {
      _highContrast = value;
    });
    await AccessibilityService.setHighContrast(value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'High contrast mode enabled' : 'High contrast mode disabled'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      // Restart app to apply theme changes
      await Future.delayed(const Duration(milliseconds: 500));
      // Note: Full theme change requires app restart
    }
  }

  Future<void> _updateFontScale(double value) async {
    setState(() {
      _fontScale = value;
    });
    await AccessibilityService.setFontScale(value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Font size updated (${(_fontScale * 100).toStringAsFixed(0)}%)'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('This will reset all accessibility settings to their default values. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AccessibilityService.resetToDefaults();
      await _loadSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to defaults'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Settings'),
        backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _resetToDefaults,
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              children: [
                // High Contrast Mode
                _buildSectionCard(
                  title: 'High Contrast Mode',
                  subtitle: 'Increases contrast for better visibility',
                  icon: Icons.contrast,
                  iconColor: const Color(0xFF3B82F6),
                  isTablet: isTablet,
                  child: SwitchListTile(
                    value: _highContrast,
                    onChanged: _updateHighContrast,
                    title: const Text('Enable High Contrast'),
                    subtitle: const Text('Uses high contrast colors for better readability'),
                  ),
                ),

                const SizedBox(height: 16),

                // Font Size Adjustment
                _buildSectionCard(
                  title: 'Font Size',
                  subtitle: 'Adjust text size throughout the app',
                  icon: Icons.text_fields,
                  iconColor: const Color(0xFF10B981),
                  isTablet: isTablet,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Font Scale: ${(_fontScale * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _updateFontScale(1.0),
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: _fontScale,
                              min: AccessibilityService.minFontScale,
                              max: AccessibilityService.maxFontScale,
                              divisions: 12, // 0.8 to 2.0 in steps of 0.1
                              label: '${(_fontScale * 100).toStringAsFixed(0)}%',
                              onChanged: _updateFontScale,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Small (${(AccessibilityService.minFontScale * 100).toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                    fontSize: (isTablet ? 12 : 10) * _fontScale,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                Text(
                                  'Normal (100%)',
                                  style: TextStyle(
                                    fontSize: (isTablet ? 12 : 10) * _fontScale,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                Text(
                                  'Large (${(AccessibilityService.maxFontScale * 100).toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                    fontSize: (isTablet ? 12 : 10) * _fontScale,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Preview text
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Preview',
                                    style: TextStyle(
                                      fontSize: (isTablet ? 14 : 12) * _fontScale,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'This is how text will appear with your current font size setting.',
                                    style: TextStyle(
                                      fontSize: (isTablet ? 14 : 13) * _fontScale,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info card
                Container(
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Some accessibility features may require restarting the app to take full effect.',
                          style: TextStyle(
                            fontSize: (isTablet ? 14 : 12) * _fontScale,
                            color: const Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isTablet,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: isTablet ? 24 : 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: (isTablet ? 18 : 16) * _fontScale,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: (isTablet ? 12 : 11) * _fontScale,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}


