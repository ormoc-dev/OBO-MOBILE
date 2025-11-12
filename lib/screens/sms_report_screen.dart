import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/inspection.dart';

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
  static const MethodChannel _smsChannel = MethodChannel('obo_mobile/sms');
  final TextEditingController _phoneController = TextEditingController();
  late final TextEditingController _messageController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSending = false;
  List<Map<String, String>> _savedContacts = [];

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: _buildSmsTemplate(),
    );
    _loadSavedContacts();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Recipient Phone Number',
            hintText: '+63 9xx xxx xxxx',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: 'Save contact',
              onPressed: _showSaveContactDialog,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Phone number is required';
            }
            return null;
          },
        ),
        if (_savedContacts.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildSavedContactsChips(isTablet),
        ],
      ],
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
          onPressed: _isSending ? null : _handleSend,
          icon: const Icon(Icons.send_rounded),
          label: _isSending
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white.withOpacity(0.3),
                  ),
                )
              : Text(
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

    if (!_isAndroid) {
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
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final smsPermission = await Permission.sms.request();
      final phonePermission = await Permission.phone.request();

      if (!smsPermission.isGranted || !phonePermission.isGranted) {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS and Phone permissions are required to send messages.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      int? subscriptionId;
      try {
        final sims = await _getSimCards();
        if (sims.length == 1) {
          subscriptionId = sims.first.subscriptionId;
        } else if (sims.length > 1) {
          subscriptionId = await _showSimPicker(sims);
          if (subscriptionId == null) {
            if (mounted) {
              setState(() {
                _isSending = false;
              });
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Failed to load SIM cards: $e');
      }

      final bool? success = await _smsChannel.invokeMethod<bool>(
        'sendSms',
        <String, dynamic>{
          'phone': phone,
          'message': message,
          if (subscriptionId != null) 'subscriptionId': subscriptionId,
        },
      );

      if (success != true) {
        throw PlatformException(code: 'SMS_SEND_FAILED', message: 'Native SMS sender returned false.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS sent successfully.'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Unable to send SMS directly.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to send SMS directly. Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
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

  Future<void> _loadSavedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sms_contacts');
    if (raw == null) return;
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      setState(() {
        _savedContacts = decoded
            .map((e) => {
                  'name': (e as Map<String, dynamic>)['name']?.toString() ?? '',
                  'phone': e['phone']?.toString() ?? '',
                })
            .where((contact) => contact['phone']!.isNotEmpty)
            .toList();
      });
    } catch (e) {
      debugPrint('Failed to load saved SMS contacts: $e');
    }
  }

  Future<void> _persistSavedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sms_contacts', jsonEncode(_savedContacts));
  }

  Future<void> _showSaveContactDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController(text: _phoneController.text.trim());

    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Contact'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Contact Name',
                  hintText: 'e.g., Business Owner',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+63 9xx xxx xxxx',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();
      if (phone.isEmpty) return;

      setState(() {
        _savedContacts.removeWhere(
            (contact) => contact['phone'] == phone || contact['name'] == name);
        _savedContacts.insert(0, {'name': name, 'phone': phone});
      });
      await _persistSavedContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact saved'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _buildSmsTemplate() {
    final inspection = widget.inspection;
    final sectionCount = _getSelectedSectionsCount(inspection);
    final statusValues = inspection.sectionStatus.values.toList();
    final status = statusValues.contains('in_progress')
        ? 'In Progress'
        : 'Completed';

    final createdDate = _formatDateTime(inspection.createdAt);
    final inspectorName =
        widget.inspectorName.isNotEmpty ? widget.inspectorName : 'Unknown Inspector';

<<<<<<< HEAD
    final buffer = StringBuffer()
      ..writeln('OBO Inspection ${inspection.id.substring(inspection.id.length - 4)}')
      ..writeln('Inspector: $inspectorName')
      ..writeln('Date: $createdDate')
      ..writeln('Business ID: ${inspection.scannedData}')
      ..writeln('Status: $status')
      ..writeln('Sections Completed: $sectionCount');

    final sectionStatus = inspection.sectionStatus;

    void appendSection({
      required String title,
      required String remarks,
      required String assessment,
      String? statusKey,
    }) {
      final statusValue = statusKey != null ? sectionStatus[statusKey] : null;
      final hasRemarks = remarks.trim().isNotEmpty;
      final hasAssessment = assessment.trim().isNotEmpty;
      final hasStatus = statusValue != null && statusValue.trim().isNotEmpty;

      if (!hasRemarks && !hasAssessment && !hasStatus) return;

      buffer.writeln();
      buffer.writeln('$title:');
      if (hasRemarks) {
        buffer.writeln(' - Remarks: ${remarks.trim()}');
      }
      if (hasAssessment) {
        buffer.writeln(' - Assessment: ${assessment.trim()}');
      }
      if (hasStatus) {
        buffer.writeln(' - Result: ${_formatSectionStatus(statusValue!)}');
      }
    }

    appendSection(
      title: 'Mechanical',
      remarks: inspection.mechanicalRemarks,
      assessment: inspection.mechanicalAssessment,
      statusKey: 'Mechanical',
    );

    appendSection(
      title: 'Line & Grade',
      remarks: inspection.lineGradeRemarks,
      assessment: inspection.lineGradeAssessment,
      statusKey: 'Line and Grade',
    );

    appendSection(
      title: 'Architectural',
      remarks: inspection.architecturalRemarks,
      assessment: inspection.architecturalAssessment,
      statusKey: 'Architectural',
    );

    appendSection(
      title: 'Civil/Structural',
      remarks: inspection.civilStructuralRemarks,
      assessment: inspection.civilStructuralAssessment,
      statusKey: 'Civil/Structural',
    );

    appendSection(
      title: 'Sanitary/Plumbing',
      remarks: inspection.sanitaryPlumbingRemarks,
      assessment: inspection.sanitaryPlumbingAssessment,
      statusKey: 'Sanitary/Plumbing',
    );

    appendSection(
      title: 'Electrical/Electronics',
      remarks: inspection.electricalElectronicsRemarks,
      assessment: inspection.electricalElectronicsAssessment,
      statusKey: 'Electrical/Electronics',
    );

    buffer.writeln();
    buffer.writeln('Thank you.');

    return buffer.toString().trim();
=======
    final permitSummary = _buildPermitSummary(inspection);

    return 'OBO Inspection ${inspection.id.substring(inspection.id.length - 4)}\n'
        'Inspector: $inspectorName\n'
        'Date: $createdDate\n'
        'Sections: $sectionCount\n'
        'Status: $status\n'
        'Business ID: ${inspection.scannedData}'
        '${permitSummary.isNotEmpty ? '\n$permitSummary' : ''}';
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
>>>>>>> version_2
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

<<<<<<< HEAD
  String _formatSectionStatus(String status) {
    switch (status) {
      case 'passed':
        return 'Passed';
      case 'not_passed':
        return 'Not Passed';
      case 'in_progress':
        return 'In Progress';
      default:
        return status;
    }
  }

  Widget _buildSavedContactsChips(bool isTablet) {
    final textStyle = TextStyle(
      fontSize: isTablet ? 13 : 11,
      fontWeight: FontWeight.w500,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved Contacts',
          style: TextStyle(
            fontSize: isTablet ? 13 : 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: isTablet ? 8 : 6,
          runSpacing: isTablet ? 6 : 4,
          children: _savedContacts.map((contact) {
            final name = contact['name'] ?? '';
            final phone = contact['phone'] ?? '';
            if (phone.isEmpty) {
              return const SizedBox.shrink();
            }
            return InputChip(
              label: Text(
                name.isNotEmpty ? '$name ($phone)' : phone,
                style: textStyle,
              ),
              onPressed: () {
                _phoneController.text = phone;
              },
              onDeleted: () async {
                setState(() {
                  _savedContacts.remove(contact);
                });
                await _persistSavedContacts();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<List<SmsSimInfo>> _getSimCards() async {
    if (!_isAndroid) {
      return [];
    }
    try {
      final List<dynamic>? raw =
          await _smsChannel.invokeMethod<List<dynamic>>('getSimCards');
      if (raw == null) {
        return [];
      }
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((entry) => SmsSimInfo.fromMap(
              Map<String, dynamic>.from(entry.map(
                  (key, value) => MapEntry(key?.toString() ?? '', value)))))
          .where((sim) => sim.subscriptionId >= 0)
          .toList();
    } catch (e) {
      debugPrint('SMS: Failed to retrieve SIM cards: $e');
      return [];
    }
  }

  Future<int?> _showSimPicker(List<SmsSimInfo> sims) async {
    if (sims.length <= 1) {
      return sims.isNotEmpty ? sims.first.subscriptionId : null;
    }

    return showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select SIM to send SMS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 0),
              ...sims.map((sim) {
                return ListTile(
                  leading: const Icon(Icons.sim_card_rounded),
                  title: Text(sim.label),
                  subtitle: sim.number != null && sim.number!.isNotEmpty
                      ? Text(sim.number!)
                      : null,
                  onTap: () => Navigator.of(context).pop(sim.subscriptionId),
                );
              }).toList(),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
=======
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
>>>>>>> version_2
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class SmsSimInfo {
  const SmsSimInfo({
    required this.subscriptionId,
    required this.slotIndex,
    this.displayName,
    this.carrierName,
    this.number,
  });

  final int subscriptionId;
  final int slotIndex;
  final String? displayName;
  final String? carrierName;
  final String? number;

  String get label {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    if (carrierName != null && carrierName!.isNotEmpty) {
      return carrierName!;
    }
    final slot = slotIndex >= 0 ? slotIndex + 1 : 1;
    return 'SIM $slot';
  }

  factory SmsSimInfo.fromMap(Map<String, dynamic> map) {
    return SmsSimInfo(
      subscriptionId: (map['subscriptionId'] as num?)?.toInt() ?? -1,
      slotIndex: (map['slotIndex'] as num?)?.toInt() ?? -1,
      displayName: map['displayName']?.toString(),
      carrierName: map['carrierName']?.toString(),
      number: map['number']?.toString(),
    );
  }
}


