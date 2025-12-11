import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/inspection.dart';
import '../services/developer_settings_service.dart';
import '../widgets/developer_settings_dialog.dart';

class SmsReportScreen extends StatefulWidget {
  final Inspection inspection;
  final String inspectorName;

  const SmsReportScreen({
    super.key,
    required this.inspection,
    required this.inspectorName,
  });

  @override
  State<SmsReportScreen> createState() => _SmsReportScreenState();
}

class _SmsReportScreenState extends State<SmsReportScreen> {
  final TextEditingController _phoneController = TextEditingController();
  late final TextEditingController _messageController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: _buildSmsTemplate(),
    );
    _loadDefaultPhoneNumber();
  }

  Future<void> _loadDefaultPhoneNumber() async {
    final defaultNumber = await DeveloperSettingsService.getDefaultSmsNumber();
    if (mounted) {
      setState(() {
        _phoneController.text = defaultNumber;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send SMS'),
        elevation: 0,
        backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
        actions: [
          IconButton(
            icon: const Icon(Icons.developer_mode),
            tooltip: 'Developer Settings',
            onPressed: _openDeveloperSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(isTablet),
                const SizedBox(height: 16),
                _buildPhoneField(isTablet),
                const SizedBox(height: 16),
                _buildMessageField(isTablet),
                const SizedBox(height: 16),
                _buildHintCard(isTablet),
                const SizedBox(height: 24),
                _buildActions(isTablet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Business ID: ${widget.inspection.scannedData}',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Review or edit the SMS content below before sending.',
            style: TextStyle(
              fontSize: isTablet ? 13 : 11,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField(bool isTablet) {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Recipient Phone Number',
        hintText: '+63 9xx xxx xxxx',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Phone number is required';
        }
        return null;
      },
    );
  }

  Widget _buildMessageField(bool isTablet) {
    return TextFormField(
      controller: _messageController,
      maxLines: 8,
      decoration: InputDecoration(
        labelText: 'SMS Message',
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Message cannot be empty';
        }
        return null;
      },
    );
  }

  Widget _buildHintCard(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sms_failed_rounded, color: Color(0xFFEA580C), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'A data or text plan is required to send SMS via your carrier. On web/desktop, the message will be copied to your clipboard so you can paste it into your messaging app.',
              style: TextStyle(
                fontSize: isTablet ? 12 : 11,
                color: const Color(0xFF9A3412),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _handleSend,
          icon: const Icon(Icons.send_rounded),
          label: Text(
            'Send SMS',
            style: TextStyle(
              fontSize: isTablet ? 15 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 16 : 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _copyToClipboard,
          icon: const Icon(Icons.copy_rounded),
          label: Text(
            'Copy Message',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 16 : 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phone = _phoneController.text.trim();
    final message = _messageController.text.trim();

    final isMobilePlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (!isMobilePlatform) {
      await Clipboard.setData(ClipboardData(text: 'To: $phone\n\n$message'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS content copied. Paste it into your messaging app.'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {
        'body': message,
      },
    );

    try {
      final launched = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open SMS app.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending SMS: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _messageController.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard.'),
          backgroundColor: Color(0xFF2563EB),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _getSectionStatusText(String sectionName) {
    final status = widget.inspection.sectionStatus[sectionName];
    if (status == null || status.isEmpty) {
      return '(section status here)';
    }
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'passed':
        return 'Passed';
      case 'not_passed':
        return 'Not Passed';
      default:
        return status;
    }
  }

  String _buildSmsTemplate() {
    final inspection = widget.inspection;
    final currentDate = DateTime.now();
    final formattedDate = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')} ${currentDate.hour.toString().padLeft(2, '0')}:${currentDate.minute.toString().padLeft(2, '0')}:${currentDate.second.toString().padLeft(2, '0')}.${currentDate.millisecond.toString().padLeft(3, '0')}';
    final inspectorName =
        widget.inspectorName.isNotEmpty ? widget.inspectorName : 'Unknown Inspector';

    // Build permit information
    final buildingPermitStatus = inspection.hasBuildingPermit == true ? 'Yes' : 'No';
    final buildingPermitRecommendation = _getPermitRecommendation(inspection.buildingPermitRecommendation);
    
    final occupancyPermitStatus = inspection.hasOccupancyPermit == true ? 'Yes' : 'No';
    String occupancyPermitIssuedLine = '';
    if (inspection.hasOccupancyPermit == true && inspection.occupancyPermitIssuedYear != null) {
      final issuedYear = inspection.occupancyPermitIssuedYear!;
      final currentYear = DateTime.now().year;
      final age = currentYear - issuedYear;
      occupancyPermitIssuedLine = '  Issued: $issuedYear (${age} year${age == 1 ? '' : 's'} old)\n';
    }
    final occupancyPermitRecommendation = _getPermitRecommendation(inspection.occupancyPermitRecommendation);
    
    // Get section statuses
    final mechanicalStatus = _getSectionStatusText('Mechanical');
    final lineGradeStatus = _getSectionStatusText('Line and Grade');
    final architecturalStatus = _getSectionStatusText('Architectural');
    final civilStructuralStatus = _getSectionStatusText('Civil/Structural');
    final sanitaryPlumbingStatus = _getSectionStatusText('Sanitary/Plumbing');
    final electricalElectronicsStatus = _getSectionStatusText('Electrical/Electronics');

    return '''INSPECTION REPORT
=================
Report Generated: $formattedDate
Inspector: $inspectorName

INSPECTION DETAILS
------------------
Business ID: ${inspection.scannedData}

PERMIT INFORMATION
------------------
Building Permit:
  Status: $buildingPermitStatus
  Recommendation: $buildingPermitRecommendation
Occupancy Permit:
  Status: $occupancyPermitStatus
$occupancyPermitIssuedLine  Recommendation: $occupancyPermitRecommendation

INSPECTION SECTIONS
-------------------
• Mechanical ($mechanicalStatus)
• Line and Grade ($lineGradeStatus)
• Architectural ($architecturalStatus)
• Civil/Structural ($civilStructuralStatus)
• Sanitary/Plumbing ($sanitaryPlumbingStatus)
• Electrical/Electronics ($electricalElectronicsStatus)
 
---
This report was generated by the OBO Mobile Inspector App.
For detailed information, please refer to the full inspection data in the mobile application.

Office of Building Official
Ormoc City''';
  }

  String _getPermitRecommendation(String? recommendation) {
    if (recommendation == null || recommendation.trim().isEmpty) return 'None';
    return recommendation;
  }

  String _buildPermitSummary(Inspection inspection) {
    final buildingStatus = _formatPermitLine(
      label: 'Building Permit',
      hasPermit: inspection.hasBuildingPermit,
      recommendation: inspection.buildingPermitRecommendation,
    );

    final occupancyStatus = _formatPermitLine(
      label: 'Occupancy Permit',
      hasPermit: inspection.hasOccupancyPermit,
      recommendation: inspection.occupancyPermitRecommendation,
      issuedYear: inspection.occupancyPermitIssuedYear,
    );

    final lines = [
      if (buildingStatus != null) buildingStatus,
      if (occupancyStatus != null) occupancyStatus,
    ];

    if (lines.isEmpty) return '';

    return 'Permits:\n${lines.join('\n')}';
  }

  int _getSelectedSectionsCount(Inspection inspection) {
    int count = 0;
    if (inspection.mechanicalRemarks.isNotEmpty || inspection.mechanicalAssessment.isNotEmpty) count++;
    if (inspection.lineGradeRemarks.isNotEmpty || inspection.lineGradeAssessment.isNotEmpty) count++;
    if (inspection.architecturalRemarks.isNotEmpty || inspection.architecturalAssessment.isNotEmpty) count++;
    if (inspection.civilStructuralRemarks.isNotEmpty || inspection.civilStructuralAssessment.isNotEmpty) count++;
    if (inspection.sanitaryPlumbingRemarks.isNotEmpty || inspection.sanitaryPlumbingAssessment.isNotEmpty) count++;
    if (inspection.electricalElectronicsRemarks.isNotEmpty || inspection.electricalElectronicsAssessment.isNotEmpty) count++;
    return count;
  }

  String? _formatPermitLine({
    required String label,
    required bool? hasPermit,
    required String? recommendation,
    int? issuedYear,
  }) {
    if (hasPermit == null && (recommendation == null || recommendation.trim().isEmpty) && issuedYear == null) {
      return null;
    }

    final status = hasPermit == null
        ? 'N/A'
        : hasPermit
            ? 'Yes'
            : 'No';

    final parts = <String>['$label: $status'];

    if (hasPermit == true && issuedYear != null) {
      final ageText = _formatOccupancyAge(issuedYear);
      parts.add(ageText);
    }

    if (recommendation != null && recommendation.trim().isNotEmpty) {
      parts.add(recommendation);
    }

    return parts.join(' · ');
  }

  String _formatOccupancyAge(int issuedYear) {
    final currentYear = DateTime.now().year;
    if (issuedYear < 1900 || issuedYear > currentYear) {
      return 'Issued: $issuedYear';
    }

    final age = currentYear - issuedYear;
    return 'Issued: $issuedYear (${age}y)';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openDeveloperSettings() async {
    final currentSms = await DeveloperSettingsService.getDefaultSmsNumber();
    final currentEmail = await DeveloperSettingsService.getDefaultEmail();
    final currentEmailCc = await DeveloperSettingsService.getDefaultEmailCc();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => DeveloperSettingsDialog(
        currentSmsNumber: currentSms,
        currentEmail: currentEmail,
        currentEmailCc: currentEmailCc,
        onSave: (smsNumber, email, emailCc) async {
          await DeveloperSettingsService.saveDefaultSmsNumber(smsNumber);
          await DeveloperSettingsService.saveDefaultEmail(email);
          await DeveloperSettingsService.saveDefaultEmailCc(emailCc);
          
          if (mounted) {
            setState(() {
              _phoneController.text = smsNumber;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Developer settings saved successfully'),
                backgroundColor: Color(0xFF10B981),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }
}


