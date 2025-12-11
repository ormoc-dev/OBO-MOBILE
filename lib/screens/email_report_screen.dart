import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../models/inspection.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/developer_settings_service.dart';
import '../widgets/developer_settings_dialog.dart';
import 'dart:io'; // <- TOP (only used for mobile)
import 'dart:convert'; // for base64
import 'dart:typed_data';
// For web ZIP download
// import 'package:archive/archive.dart';
// import 'package:universal_html/html.dart' as html;

class EmailReportScreen extends StatefulWidget {
  final Inspection inspection;
  final bool isDetailed;

  const EmailReportScreen({
    super.key,
    required this.inspection,
    this.isDetailed = false,
  });

  @override
  State<EmailReportScreen> createState() => _EmailReportScreenState();
}

class _EmailReportScreenState extends State<EmailReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientsController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _ccController = TextEditingController();
  final _bccController = TextEditingController();
  
  bool _isLoading = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _recipientsController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      final user = await AuthService.getCurrentUser();
      setState(() {
        _currentUser = user;
      });
      
      // Pre-fill form with inspection data
      _subjectController.text = _buildEmailSubject();
      
      // Use text format for mobile (better compatibility), HTML for web
      if (kIsWeb) {
        _bodyController.text = widget.isDetailed ? _generateTextReport(detailed: true) : _generateTextReport(detailed: false);
      } else {
        // On mobile, use plain text format for better email client compatibility
        _bodyController.text = widget.isDetailed ? _generateTextReport(detailed: true) : _generateTextReport(detailed: false);
      }
      
      // Load default email settings from developer settings
      final defaultEmail = await DeveloperSettingsService.getDefaultEmail();
      final defaultEmailCc = await DeveloperSettingsService.getDefaultEmailCc();
      
      _recipientsController.text = defaultEmail;
      _ccController.text = defaultEmailCc;
    } catch (e) {
      print('Error initializing email data: $e');
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

  String _generateQuickReport() {
    final currentDate = DateTime.now();
    final inspectorName = _currentUser?.name ?? 'Unknown Inspector';
    final formattedDate = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')} ${currentDate.hour.toString().padLeft(2, '0')}:${currentDate.minute.toString().padLeft(2, '0')}:${currentDate.second.toString().padLeft(2, '0')}.${currentDate.millisecond.toString().padLeft(3, '0')}';
    
    // Build permit information
    final buildingPermitStatus = widget.inspection.hasBuildingPermit == true ? 'Yes' : 'No';
    final buildingPermitRecommendation = _permitRecommendationText(widget.inspection.buildingPermitRecommendation);
    
    final occupancyPermitStatus = widget.inspection.hasOccupancyPermit == true ? 'Yes' : 'No';
    String occupancyPermitIssued = '';
    String occupancyPermitIssuedLine = '';
    if (widget.inspection.hasOccupancyPermit == true && widget.inspection.occupancyPermitIssuedYear != null) {
      final issuedYear = widget.inspection.occupancyPermitIssuedYear!;
      final currentYear = DateTime.now().year;
      final age = currentYear - issuedYear;
      occupancyPermitIssued = '$issuedYear (${age} year${age == 1 ? '' : 's'} old)';
      occupancyPermitIssuedLine = '  Issued: $occupancyPermitIssued\n';
    }
    final occupancyPermitRecommendation = _permitRecommendationText(widget.inspection.occupancyPermitRecommendation);
    
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
Business ID: ${widget.inspection.scannedData}

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
Ormoc City
''';
  }

  String _buildEmailSubject() {
    final qrData = widget.inspection.scannedData.toString().trim();
    return 'business id inspected: ${qrData.isNotEmpty ? qrData : ''}'.trim();
  }

  Future<String> _generateHtmlReport({required bool detailed}) async {
    final currentDate = DateTime.now();
    final inspectorName = _currentUser?.name ?? 'Unknown Inspector';
    final formattedDate = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')} ${currentDate.hour.toString().padLeft(2, '0')}:${currentDate.minute.toString().padLeft(2, '0')}:${currentDate.second.toString().padLeft(2, '0')}.${currentDate.millisecond.toString().padLeft(3, '0')}';

    // Build permit information
    final buildingPermitStatus = widget.inspection.hasBuildingPermit == true ? 'Yes' : 'No';
    final buildingPermitRecommendation = _permitRecommendationText(widget.inspection.buildingPermitRecommendation);
    
    final occupancyPermitStatus = widget.inspection.hasOccupancyPermit == true ? 'Yes' : 'No';
    String occupancyPermitIssued = '';
    String occupancyPermitIssuedHtml = '';
    if (widget.inspection.hasOccupancyPermit == true && widget.inspection.occupancyPermitIssuedYear != null) {
      final issuedYear = widget.inspection.occupancyPermitIssuedYear!;
      final currentYear = DateTime.now().year;
      final age = currentYear - issuedYear;
      occupancyPermitIssued = '$issuedYear (${age} year${age == 1 ? '' : 's'} old)';
      occupancyPermitIssuedHtml = '<div>Issued: ${_escapeHtml(occupancyPermitIssued)}</div>';
    }
    final occupancyPermitRecommendation = _permitRecommendationText(widget.inspection.occupancyPermitRecommendation);
    
    // Get section statuses
    final mechanicalStatus = _getSectionStatusText('Mechanical');
    final lineGradeStatus = _getSectionStatusText('Line and Grade');
    final architecturalStatus = _getSectionStatusText('Architectural');
    final civilStructuralStatus = _getSectionStatusText('Civil/Structural');
    final sanitaryPlumbingStatus = _getSectionStatusText('Sanitary/Plumbing');
    final electricalElectronicsStatus = _getSectionStatusText('Electrical/Electronics');

    final fontFamily = "'Segoe UI', Helvetica, Arial, sans-serif";
    return '''
<div style="font-family:$fontFamily; color:#111827; padding:20px; max-width:700px; margin:0 auto;">
  <h1 style="margin:0 0 20px 0; color:#1f2937; font-size:24px; font-weight:bold; border-bottom:3px solid #3b82f6; padding-bottom:10px;">INSPECTION REPORT</h1>
  <div style="margin-bottom:20px; font-size:14px; color:#374151;">
    <div><strong>Report Generated:</strong> ${_escapeHtml(formattedDate)}</div>
    <div><strong>Inspector:</strong> ${_escapeHtml(inspectorName)}</div>
  </div>

  <div style="margin-bottom:20px;">
    <h2 style="margin:0 0 10px 0; color:#1f2937; font-size:18px; font-weight:bold; border-bottom:2px solid #e5e7eb; padding-bottom:5px;">INSPECTION DETAILS</h2>
    <div style="font-size:14px; color:#374151;">
      <div><strong>Business ID:</strong> ${_escapeHtml(widget.inspection.scannedData.toString())}</div>
    </div>
  </div>

  <div style="margin-bottom:20px;">
    <h2 style="margin:0 0 10px 0; color:#1f2937; font-size:18px; font-weight:bold; border-bottom:2px solid #e5e7eb; padding-bottom:5px;">PERMIT INFORMATION</h2>
    <div style="font-size:14px; color:#374151; line-height:1.8;">
      <div><strong>Building Permit:</strong></div>
      <div style="margin-left:20px;">
        <div>Status: ${_escapeHtml(buildingPermitStatus)}</div>
        <div>Recommendation: ${_escapeHtml(buildingPermitRecommendation)}</div>
      </div>
      <div style="margin-top:10px;"><strong>Occupancy Permit:</strong></div>
      <div style="margin-left:20px;">
        <div>Status: ${_escapeHtml(occupancyPermitStatus)}</div>
        $occupancyPermitIssuedHtml
        <div>Recommendation: ${_escapeHtml(occupancyPermitRecommendation)}</div>
      </div>
    </div>
  </div>

  <div style="margin-bottom:20px;">
    <h2 style="margin:0 0 10px 0; color:#1f2937; font-size:18px; font-weight:bold; border-bottom:2px solid #e5e7eb; padding-bottom:5px;">INSPECTION SECTIONS</h2>
    <div style="font-size:14px; color:#374151; line-height:1.8;">
      <div>• Mechanical (${_escapeHtml(mechanicalStatus)})</div>
      <div>• Line and Grade (${_escapeHtml(lineGradeStatus)})</div>
      <div>• Architectural (${_escapeHtml(architecturalStatus)})</div>
      <div>• Civil/Structural (${_escapeHtml(civilStructuralStatus)})</div>
      <div>• Sanitary/Plumbing (${_escapeHtml(sanitaryPlumbingStatus)})</div>
      <div>• Electrical/Electronics (${_escapeHtml(electricalElectronicsStatus)})</div>
    </div>
  </div>

  <div style="margin-top:30px; padding-top:20px; border-top:2px solid #e5e7eb; font-size:12px; color:#6b7280; text-align:center;">
    <div>This report was generated by the OBO Mobile Inspector App.</div>
    <div>For detailed information, please refer to the full inspection data in the mobile application.</div>
    <div style="margin-top:10px; font-weight:bold; color:#1f2937;">Office of Building Official</div>
    <div style="font-weight:bold; color:#1f2937;">Ormoc City</div>
  </div>
</div>
''';
  }

  String _generateTextReport({required bool detailed}) {
    // Use the same format for both detailed and quick reports
    return _generateQuickReport();
  }

  String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _basename(String path) {
    final idx = path.replaceAll('\\\\', '/').lastIndexOf('/');
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  String _generateDetailedReport() {
    // Use the same format as quick report
    return _generateQuickReport();
  }

  bool _hasPermitInfo() {
    final inspection = widget.inspection;
    return inspection.hasBuildingPermit != null ||
        inspection.hasOccupancyPermit != null ||
        inspection.occupancyPermitIssuedYear != null ||
        (inspection.buildingPermitRecommendation?.trim().isNotEmpty ?? false) ||
        (inspection.occupancyPermitRecommendation?.trim().isNotEmpty ?? false);
  }

  String _permitStatusText(bool? value) {
    if (value == null) return 'Not provided';
    return value ? 'Yes' : 'No';
  }

  String _permitRecommendationText(String? recommendation) {
    if (recommendation == null || recommendation.trim().isEmpty) return 'None';
    return recommendation;
  }

  String _occupancyAgeText(int? issuedYear) {
    if (issuedYear == null) return 'Issued year not available';
    final currentYear = DateTime.now().year;
    if (issuedYear < 1900 || issuedYear > currentYear) {
      return 'Issued: $issuedYear';
    }
    final age = currentYear - issuedYear;
    return 'Issued: $issuedYear (${age} year${age == 1 ? '' : 's'} old)';
  }

  bool _isOccupancyCaution(Inspection inspection) {
    return inspection.hasOccupancyPermit == true &&
        (inspection.occupancyPermitRecommendation != null &&
            inspection.occupancyPermitRecommendation != 'Approved');
  }

  String _buildPermitSummaryText() {
    if (!_hasPermitInfo()) {
      return 'Permit Summary:\n- Building Permit: Not provided\n- Occupancy Permit: Not provided';
    }

    final inspection = widget.inspection;

    final buildingLine =
        '- Building Permit: ${_permitStatusText(inspection.hasBuildingPermit)}'
        ' | Recommendation: ${_permitRecommendationText(inspection.buildingPermitRecommendation)}';

    final occupancyLine =
        '- Occupancy Permit: ${_permitStatusText(inspection.hasOccupancyPermit)}'
        ' | ${_occupancyAgeText(inspection.occupancyPermitIssuedYear)}'
        ' | Recommendation: ${_permitRecommendationText(inspection.occupancyPermitRecommendation)}';

    return 'Permit Summary:\n$buildingLine\n$occupancyLine';
  }

  String _buildPermitDetailedText() {
    if (!_hasPermitInfo()) {
      return 'Building Permit: Not provided\nOccupancy Permit: Not provided\n';
    }

    final inspection = widget.inspection;

    final building = 'Building Permit:\n'
        '  Status: ${_permitStatusText(inspection.hasBuildingPermit)}\n'
        '  Recommendation: ${_permitRecommendationText(inspection.buildingPermitRecommendation)}\n';

    final occupancy = 'Occupancy Permit:\n'
        '  Status: ${_permitStatusText(inspection.hasOccupancyPermit)}\n'
        '  ${_occupancyAgeText(inspection.occupancyPermitIssuedYear)}\n'
        '  Recommendation: ${_permitRecommendationText(inspection.occupancyPermitRecommendation)}\n';

    return '$building$occupancy';
  }

  String _buildPermitHtmlBlock() {
    if (!_hasPermitInfo()) return '';

    final inspection = widget.inspection;

    final buildingStatus = _permitStatusText(inspection.hasBuildingPermit);
    final buildingRecommendation = _permitRecommendationText(inspection.buildingPermitRecommendation);

    final occupancyStatus = _permitStatusText(inspection.hasOccupancyPermit);
    final occupancyRecommendation = _permitRecommendationText(inspection.occupancyPermitRecommendation);
    final occupancyAge = _occupancyAgeText(inspection.occupancyPermitIssuedYear);

    final buildingColor = inspection.hasBuildingPermit == true ? '#10B981' : '#EF4444';
    final occupancyColor = inspection.hasOccupancyPermit == true
        ? (_isOccupancyCaution(inspection) ? '#F97316' : '#10B981')
        : '#EF4444';

    final buildingIcon = inspection.hasBuildingPermit == true ? '✅' : '❌';
    final occupancyIcon = inspection.hasOccupancyPermit == true
        ? (_isOccupancyCaution(inspection) ? '⚠️' : '✅')
        : '❌';

    return '''
    <div style="margin-bottom:18px; border:1px solid #e2e8f0; border-radius:10px; overflow:hidden; background:#f9fafb;">
      <div style="background:#f1f5f9; padding:12px 16px; font-size:14px; font-weight:600; color:#1f2937; letter-spacing:0.3px;">
        Permit Overview
      </div>
      <div style="display:flex; flex-wrap:wrap; gap:12px; padding:14px 16px;">
        <div style="flex:1 1 220px; border:1px solid ${buildingColor}3D; border-radius:10px; padding:12px; background:${buildingColor}14;">
          <div style="font-size:13px; font-weight:600; color:$buildingColor;">$buildingIcon Building Permit</div>
          <div style="margin-top:6px; font-size:12px; color:#1f2937;">Status: <b>$buildingStatus</b></div>
          <div style="margin-top:6px; font-size:12px; color:#1f2937;">Recommendation: $buildingRecommendation</div>
        </div>
        <div style="flex:1 1 220px; border:1px solid ${occupancyColor}3D; border-radius:10px; padding:12px; background:${occupancyColor}14;">
          <div style="font-size:13px; font-weight:600; color:$occupancyColor;">$occupancyIcon Occupancy Permit</div>
          <div style="margin-top:6px; font-size:12px; color:#1f2937;">Status: <b>$occupancyStatus</b></div>
          <div style="margin-top:6px; font-size:12px; color:#1f2937;">$occupancyAge</div>
          <div style="margin-top:6px; font-size:12px; color:#1f2937;">Recommendation: $occupancyRecommendation</div>
        </div>
      </div>
    </div>
    ''';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _calculateDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if running on web
      if (kIsWeb) {
        print('Running on web - using mailto');
        await _sendEmailViaWeb();
        return;
      }

      // Mobile platform - use flutter_email_sender
      // Use plain text format on mobile for better compatibility with email clients
      final emailBody = widget.isDetailed ? _generateTextReport(detailed: true) : _generateTextReport(detailed: false);
      final Email email = Email(
        body: emailBody,
        subject: _buildEmailSubject(),
        recipients: _recipientsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        cc: _ccController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        bcc: _bccController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        attachmentPaths: [
          ...widget.inspection.imagePaths,
          ...widget.inspection.videoPaths,
        ],
        isHTML: false, // Use plain text on mobile to avoid HTML code display issues
      );

      print('Attempting to send email to: ${email.recipients}');
      await FlutterEmailSender.send(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email client opened successfully! Please complete sending from your email app.'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Email sending error: $e');
      if (mounted) {
        String errorMessage = 'Failed to open email client. ';
        
        if (e.toString().contains('MissingPluginException')) {
          errorMessage += 'Plugin not supported on web. Using web email method instead.';
          // Automatically try web method as fallback
          await _sendEmailViaWeb();
          return;
        } else if (e.toString().contains('No email client')) {
          errorMessage += 'Please install an email app like Gmail or Outlook.';
        } else if (e.toString().contains('permission')) {
          errorMessage += 'Please check app permissions.';
        } else {
          errorMessage += 'Error: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  

  Future<void> _sendEmailViaWeb() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create mailto URL
      final recipients = _recipientsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).join(',');
      final cc = _ccController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).join(',');
      final subject = Uri.encodeComponent(_buildEmailSubject());
      final body = Uri.encodeComponent(_generateTextReport(detailed: widget.isDetailed));
      
      String mailtoUrl = 'mailto:$recipients';
      List<String> params = [];
      
      if (subject.isNotEmpty) params.add('subject=$subject');
      if (body.isNotEmpty) params.add('body=$body');
      if (cc.isNotEmpty) params.add('cc=$cc');
      
      if (params.isNotEmpty) {
        mailtoUrl += '?${params.join('&')}';
      }
      
      print('Opening mailto URL: $mailtoUrl');
      
      final Uri emailUri = Uri.parse(mailtoUrl);
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email client opened via web! Please complete sending from your email app.'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Could not launch email client');
      }
    } catch (e) {
      print('Web email sending error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open email client: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<String>> _inlineImageHtmlList() async {
    List<String> htmls = [];
    for (final path in widget.inspection.imagePaths) {
      try {
        String base64Str;
        String ext = path.split('.').last.toLowerCase();
        String mimeType = (ext == 'png')
          ? 'image/png'
          : (ext == 'jpg' || ext == 'jpeg'
              ? 'image/jpeg'
              : 'image/*');
        Uint8List bytes;
        if (kIsWeb) {
          // On web, assume path is a blob/DataUrl already!
          // We can't synchronously fetch raw bytes from web FileSystem.
          base64Str = path; // fallback display as img src
        } else {
          final file = File(path);
          if (!await file.exists()) continue;
          bytes = await file.readAsBytes();
          base64Str = base64Encode(bytes);
        }
        // On web base64Str may already be a dataUrl, else build it.
        final src = kIsWeb && path.startsWith('data:')
            ? path
            : 'data:$mimeType;base64,$base64Str';
        htmls.add('<div style="margin:6px 0"><img src="$src" style="max-width:170px; border-radius:8px; border:1px solid #e2e8f0; box-shadow:0 2px 10px #0002;" /><div style="font-size:12px; color:#666">${_escapeHtml(_basename(path))}</div></div>');
      } catch (e) {
        htmls.add('<div><span style="color:#ff0000">(Failed to attach image: ${_escapeHtml(_basename(path))})</span></div>');
      }
    }
    return htmls;
  }

  Future<List<String>> _inlineVideoList() async {
    // Embedding playable video isn't supported by email clients. So just list filenames, maybe thumbnail later.
    List<String> htmls = [];
    for (final path in widget.inspection.videoPaths) {
      htmls.add('<div style="margin:3px 0; color:#374151;"><span style="font-size:15px;">🎬 ${_escapeHtml(_basename(path))}</span></div>');
    }
    return htmls;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isDetailed ? 'Send Detailed Report' : 'Send Quick Report',
          style: TextStyle(
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.developer_mode),
            tooltip: 'Developer Settings',
            onPressed: _openDeveloperSettings,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _sendEmail,
              child: const Text(
                'Send',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Inspection Info Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isTablet ? 20 : 16),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.assessment_rounded,
                            color: Color(0xFF3B82F6),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inspection Report',
                                style: TextStyle(
                                  fontSize: isTablet ? 18 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                'ID: ${widget.inspection.id.substring(widget.inspection.id.length - 8)}',
                                style: TextStyle(
                                  fontSize: isTablet ? 12 : 10,
                                  color: const Color(0xFF6B7280),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 12 : 8,
                            vertical: isTablet ? 6 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isDetailed 
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.isDetailed ? 'Detailed' : 'Quick',
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildInfoChip('Photos', widget.inspection.imagePaths.length.toString(), Icons.photo_camera_rounded, isTablet),
                        const SizedBox(width: 8),
                        _buildInfoChip('Videos', widget.inspection.videoPaths.length.toString(), Icons.videocam_rounded, isTablet),
                        const SizedBox(width: 8),
                        _buildInfoChip('Status', widget.inspection.isSynced ? 'Synced' : 'Pending', 
                            widget.inspection.isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, isTablet),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Email Form
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isTablet ? 20 : 16),
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
                    Text(
                      'Email Details',
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Recipients
                    _buildTextField(
                      controller: _recipientsController,
                      label: 'Recipients',
                      hint: 'Enter email addresses (comma-separated)',
                      icon: Icons.email_outlined,
                      isRequired: true,
                      isTablet: isTablet,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Subject
                    _buildTextField(
                      controller: _subjectController,
                      label: 'Subject',
                      hint: 'Enter email subject',
                      icon: Icons.subject_outlined,
                      isRequired: true,
                      isTablet: isTablet,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // CC
                    _buildTextField(
                      controller: _ccController,
                      label: 'CC (Optional)',
                      hint: 'Enter CC email addresses',
                      icon: Icons.copy_outlined,
                      isRequired: false,
                      isTablet: isTablet,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // BCC
                    _buildTextField(
                      controller: _bccController,
                      label: 'BCC (Optional)',
                      hint: 'Enter BCC email addresses',
                      icon: Icons.visibility_off_outlined,
                      isRequired: false,
                      isTablet: isTablet,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Body
                    _buildTextField(
                      controller: _bodyController,
                      label: 'Message Body',
                      hint: 'Enter your message',
                      icon: Icons.message_outlined,
                      isRequired: true,
                      isTablet: isTablet,
                      maxLines: 8,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Attachments Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isTablet ? 20 : 16),
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
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_file_rounded,
                          color: Color(0xFF3B82F6),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Attachments',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'After opening your email client, you can manually attach inspection photos and videos.',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    if (widget.inspection.imagePaths.isNotEmpty || widget.inspection.videoPaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF0EA5E9),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This inspection has ${widget.inspection.imagePaths.length} photos and ${widget.inspection.videoPaths.length} videos. You can attach them manually in your email client.',
                                style: TextStyle(
                                  fontSize: isTablet ? 12 : 10,
                                  color: const Color(0xFF0EA5E9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Send Buttons
              Column(
                children: [
                  // Primary Send Button
                  SizedBox(
                    width: double.infinity,
                    height: isTablet ? 56 : 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _sendEmail,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                      label: Text(
                        _isLoading ? 'Sending...' : 'Send Email',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  
                  if (!kIsWeb) ...[
                    const SizedBox(height: 12),
                    
                    // Alternative Send Button (only show on mobile)
                    SizedBox(
                      width: double.infinity,
                      height: isTablet ? 48 : 44,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _sendEmailViaWeb,
                        icon: const Icon(Icons.web_rounded, color: Color(0xFF3B82F6)),
                        label: Text(
                          'Send via Web Email',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Help text (only show on mobile)
                    Text(
                      'If the first option fails, try the web email option',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: const Color(0xFF6B7280),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    
                    // Help text for web
                    Text(
                      'Email will open in your default email client',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: const Color(0xFF6B7280),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isRequired,
    required bool isTablet,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF3B82F6), size: isTablet ? 18 : 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: isRequired ? (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This field is required';
            }
            return null;
          } : null,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 16 : 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 8,
        vertical: isTablet ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF0EA5E9), size: isTablet ? 14 : 12),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: isTablet ? 12 : 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0EA5E9),
            ),
          ),
        ],
      ),
    );
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
              _recipientsController.text = email;
              _ccController.text = emailCc;
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
