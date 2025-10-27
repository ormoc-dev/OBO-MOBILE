import 'package:flutter/material.dart';
import 'dart:math';
import '../models/inspection.dart';
import '../services/hive_offline_database.dart';
import '../services/auth_service.dart';
import '../widgets/map_widget.dart';
import '../widgets/media_capture_widget.dart';
import 'package:latlong2/latlong.dart';

class InspectionFormScreen extends StatefulWidget {
  final String? scannedData;
  
  const InspectionFormScreen({super.key, this.scannedData});

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Section selection
  Map<String, bool> _selectedSections = {};

  // Controllers for each section
  final Map<String, TextEditingController> _remarksControllers = {};
  final Map<String, TextEditingController> _assessmentControllers = {};
  
  // Status for each section
  final Map<String, String> _sectionStatus = {};
  
  // Location data for Civil/Structural section
  LatLng? _civilStructuralLocation;
  
  // Media capture data
  List<String> _imagePaths = [];
  List<String> _videoPaths = [];
  
  // Inspection timing
  DateTime? _inspectionStartTime;
  DateTime? _inspectionEndTime;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // Initialize section selection map
    _selectedSections = {
      'Mechanical': false,
      'Line and Grade': false,
      'Architectural': false,
      'Civil/Structural': false,
      'Sanitary/Plumbing': false,
      'Electrical/Electronics': false,
    };

    // Initialize controllers and status
    for (String section in _selectedSections.keys) {
      _remarksControllers[section] = TextEditingController();
      _assessmentControllers[section] = TextEditingController();
      _sectionStatus[section] = 'field'; // Default status
    }
    
    // Set inspection start time when form is initialized
    _inspectionStartTime = DateTime.now();
  }

  @override
  void dispose() {
    for (var controller in _remarksControllers.values) {
      controller.dispose();
    }
    for (var controller in _assessmentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF8FAFC),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 32.0 : 16.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context, isTablet),
                  const SizedBox(height: 24),
                  
                  // Scanned Data Info
                  _buildScannedDataCard(context, isTablet),
                  const SizedBox(height: 24),
                  
                  // Inspection Timing
                  _buildInspectionTimingCard(context, isTablet),
                  const SizedBox(height: 24),
                  
                  // Section Selection
                  _buildSectionSelection(context, isTablet),
                  const SizedBox(height: 24),
                  
                  // Selected Sections
                  ..._buildSelectedSections(context, isTablet),
                  
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  _buildSubmitButton(context, isTablet),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildCalculatorFAB(context, isTablet),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            offset: Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inspection Form',
                  style: TextStyle(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete inspection details',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannedDataCard(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Scanned QR Code Data',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Text(
              widget.scannedData ?? 'No data available',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: const Color(0xFF374151),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionTimingCard(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Inspection Timing',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Start Time
          Row(
            children: [
              Expanded(
                child: _buildTimeField(
                  'Start Time',
                  _inspectionStartTime,
                  Icons.play_arrow_rounded,
                  const Color(0xFF10B981),
                  isTablet,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: _buildTimeField(
                  'End Time',
                  _inspectionEndTime,
                  Icons.stop_rounded,
                  const Color(0xFFEF4444),
                  isTablet,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Duration calculation
          if (_inspectionStartTime != null && _inspectionEndTime != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(0),
                border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_rounded,
                    color: Color(0xFF0EA5E9),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${_calculateDuration()}',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: const Color(0xFF0EA5E9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, DateTime? time, IconData icon, Color color, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _selectTime(label),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: isTablet ? 20 : 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    time != null 
                        ? '${time.day}/${time.month}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                        : 'Tap to set $label',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: time != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                      fontWeight: time != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(String type) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: type == 'Start Time' 
          ? (_inspectionStartTime ?? DateTime.now())
          : (_inspectionEndTime ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: type == 'Start Time' 
            ? TimeOfDay.fromDateTime(_inspectionStartTime ?? DateTime.now())
            : TimeOfDay.fromDateTime(_inspectionEndTime ?? DateTime.now()),
      );

      if (pickedTime != null) {
        final DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (type == 'Start Time') {
            _inspectionStartTime = selectedDateTime;
          } else {
            _inspectionEndTime = selectedDateTime;
          }
        });
      }
    }
  }

  String _calculateDuration() {
    if (_inspectionStartTime == null || _inspectionEndTime == null) {
      return 'N/A';
    }

    final duration = _inspectionEndTime!.difference(_inspectionStartTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Widget _buildSectionSelection(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Select Inspection Sections',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Choose which sections you want to inspect:',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _selectedSections.isNotEmpty 
                ? _selectedSections.keys.map((section) {
                    return _buildSectionChip(section, isTablet);
                  }).toList()
                : [],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionChip(String section, bool isTablet) {
    final isSelected = _selectedSections[section] ?? false;
    final sectionData = _getSectionData(section);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSections[section] = !isSelected;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 12 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? sectionData['color'] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? sectionData['color'] : const Color(0xFFE2E8F0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? sectionData['color'].withOpacity(0.2) : const Color(0xFFE2E8F0),
              offset: const Offset(0, 2),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sectionData['icon'],
              color: isSelected ? Colors.white : sectionData['color'],
              size: isTablet ? 20 : 18,
            ),
            const SizedBox(width: 8),
            Text(
              section,
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSelectedSections(BuildContext context, bool isTablet) {
    if (_selectedSections.isEmpty) {
      return [];
    }
    
    final selectedSections = _selectedSections.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedSections.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: const Color(0xFF6B7280),
                size: isTablet ? 48 : 40,
              ),
              const SizedBox(height: 16),
              Text(
                'No sections selected',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please select at least one inspection section above.',
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }

    return selectedSections.map((section) {
      final sectionData = _getSectionData(section);
      return Column(
        children: [
          _buildDynamicSectionCard(
            context,
            isTablet,
            section,
            sectionData['icon'],
            sectionData['color'],
          ),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  Map<String, dynamic> _getSectionData(String section) {
    switch (section) {
      case 'Mechanical':
        return {
          'icon': Icons.build_rounded,
          'color': const Color(0xFF10B981),
        };
      case 'Line and Grade':
        return {
          'icon': Icons.straighten_rounded,
          'color': const Color(0xFF3B82F6),
        };
      case 'Architectural':
        return {
          'icon': Icons.architecture_rounded,
          'color': const Color(0xFF8B5CF6),
        };
      case 'Civil/Structural':
        return {
          'icon': Icons.construction_rounded,
          'color': const Color(0xFFF59E0B),
        };
      case 'Sanitary/Plumbing':
        return {
          'icon': Icons.plumbing_rounded,
          'color': const Color(0xFF06B6D4),
        };
      case 'Electrical/Electronics':
        return {
          'icon': Icons.electrical_services_rounded,
          'color': const Color(0xFFEF4444),
        };
      default:
        return {
          'icon': Icons.construction_rounded,
          'color': const Color(0xFF6B7280),
        };
    }
  }

  Widget _buildDynamicSectionCard(
    BuildContext context,
    bool isTablet,
    String title,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3748),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Status Selection
          _buildStatusSelection(title, isTablet, color),
          const SizedBox(height: 20),
          
          // Map for Civil/Structural section
          if (title == 'Civil/Structural') ...[
            _buildMapSection(title, isTablet, color),
            const SizedBox(height: 20),
          ],
          
          // Remarks Field
          Text(
            'Remarks',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _remarksControllers[title],
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter remarks for $title...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          
          // Assessment Field
          Text(
            'Assessment',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _assessmentControllers[title],
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter assessment for $title...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),
          
          // Media Capture Section
          _buildMediaCaptureSection(title, isTablet, color),
        ],
      ),
    );
  }

  Widget _buildStatusSelection(String section, bool isTablet, Color color) {
    final currentStatus = _sectionStatus[section] ?? 'field';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildStatusChip(
              'Field',
              'field',
              currentStatus,
              const Color(0xFF6B7280),
              Icons.location_on_rounded,
              isTablet,
              () => _updateStatus(section, 'field'),
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              'In Progress',
              'in_progress',
              currentStatus,
              const Color(0xFFF59E0B),
              Icons.hourglass_empty_rounded,
              isTablet,
              () => _updateStatus(section, 'in_progress'),
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              'Passed',
              'passed',
              currentStatus,
              const Color(0xFF10B981),
              Icons.check_circle_rounded,
              isTablet,
              () => _updateStatus(section, 'passed'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(
    String label,
    String value,
    String currentStatus,
    Color color,
    IconData icon,
    bool isTablet,
    VoidCallback onTap,
  ) {
    final isSelected = currentStatus == value;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 12 : 8,
          vertical: isTablet ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: isTablet ? 16 : 14,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(String section, String status) {
    setState(() {
      _sectionStatus[section] = status;
    });
  }

  Widget _buildMediaCaptureSection(String title, bool isTablet, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.photo_camera_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Media Capture (Optional)',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Add photos or videos to document your inspection:',
          style: TextStyle(
            fontSize: isTablet ? 12 : 10,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 12),
        MediaCaptureWidget(
          imagePaths: _imagePaths,
          videoPaths: _videoPaths,
          onImagesChanged: (images) {
            setState(() {
              _imagePaths = images;
            });
          },
          onVideosChanged: (videos) {
            setState(() {
              _videoPaths = videos;
            });
          },
          isTablet: isTablet,
        ),
      ],
    );
  }

  Widget _buildMapSection(String title, bool isTablet, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.map_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Location Mapping',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tap on the map to mark the inspection location:',
          style: TextStyle(
            fontSize: isTablet ? 12 : 10,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 12),
        MapWidget(
          title: 'Civil/Structural Inspection Location',
          initialLocation: _civilStructuralLocation,
          onLocationSelected: (location) {
            setState(() {
              _civilStructuralLocation = location;
            });
          },
        ),
        if (_civilStructuralLocation != null) ...[
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
                  Icons.check_circle,
                  color: Color(0xFF0EA5E9),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location marked: ${_civilStructuralLocation!.latitude.toStringAsFixed(4)}, ${_civilStructuralLocation!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0EA5E9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context, bool isTablet) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 16 : 14,
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save_rounded, color: Colors.white, size: 20),
            SizedBox(width: isTablet ? 12 : 8),
            Text(
              'Submit Inspection',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() async {
    // Check if at least one section is selected
    if (_selectedSections.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Sections Available'),
          content: const Text('Please wait for the form to load completely.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    final selectedSections = _selectedSections.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedSections.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Sections Selected'),
          content: const Text('Please select at least one inspection section before submitting.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        // Set inspection end time when submitting
        _inspectionEndTime = DateTime.now();
        
        // Get current user ID
        final currentUser = await AuthService.getCurrentUser();
        final userId = currentUser?.id.toString();

        // Create inspection object with dynamic data
        final inspection = Inspection.fromFormData(
          scannedData: widget.scannedData ?? 'No QR data',
          mechanicalRemarks: _getSectionText('Mechanical', 'remarks'),
          mechanicalAssessment: _getSectionText('Mechanical', 'assessment'),
          lineGradeRemarks: _getSectionText('Line and Grade', 'remarks'),
          lineGradeAssessment: _getSectionText('Line and Grade', 'assessment'),
          architecturalRemarks: _getSectionText('Architectural', 'remarks'),
          architecturalAssessment: _getSectionText('Architectural', 'assessment'),
          civilStructuralRemarks: _getSectionText('Civil/Structural', 'remarks'),
          civilStructuralAssessment: _getSectionText('Civil/Structural', 'assessment'),
          sanitaryPlumbingRemarks: _getSectionText('Sanitary/Plumbing', 'remarks'),
          sanitaryPlumbingAssessment: _getSectionText('Sanitary/Plumbing', 'assessment'),
          electricalElectronicsRemarks: _getSectionText('Electrical/Electronics', 'remarks'),
          electricalElectronicsAssessment: _getSectionText('Electrical/Electronics', 'assessment'),
          userId: userId,
          latitude: _civilStructuralLocation?.latitude,
          longitude: _civilStructuralLocation?.longitude,
          imagePaths: _imagePaths,
          videoPaths: _videoPaths,
          inspectionStartTime: _inspectionStartTime,
          inspectionEndTime: _inspectionEndTime,
        );

        // Save to Hive database
        await HiveOfflineDatabase.saveInspection(inspection);
        
        // Mark as synced since it's saved locally (offline-first approach)
        await HiveOfflineDatabase.markInspectionAsSynced(inspection.id);
        
        print('Inspection saved to Hive: ${inspection.id}');
        print('Scanned data: ${inspection.scannedData}');
        print('Selected sections: $selectedSections');
        print('Images captured: ${_imagePaths.length}');
        print('Videos captured: ${_videoPaths.length}');
        print('Inspection duration: ${_calculateDuration()}');

        // Show success dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Inspection Submitted'),
              content: Text('Your inspection for ${selectedSections.length} section(s) has been saved successfully${_imagePaths.isNotEmpty || _videoPaths.isNotEmpty ? ' with ${_imagePaths.length} photo(s) and ${_videoPaths.length} video(s)' : ''}${_inspectionStartTime != null && _inspectionEndTime != null ? ' (Duration: ${_calculateDuration()})' : ''} and will be synced when online.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to previous screen
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        print('Error saving inspection: $e');
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to save inspection: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  String _getSectionText(String section, String type) {
    if (type == 'remarks') {
      return _remarksControllers[section]?.text ?? '';
    } else if (type == 'assessment') {
      return _assessmentControllers[section]?.text ?? '';
    }
    return '';
  }

  Widget _buildCalculatorFAB(BuildContext context, bool isTablet) {
    return FloatingActionButton(
      onPressed: () => _showCalculator(context, isTablet),
      backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
      foregroundColor: Colors.white,
      elevation: 8,
      child: const Icon(Icons.calculate_rounded, size: 28),
    );
  }

  void _showCalculator(BuildContext context, bool isTablet) {
    showDialog(
      context: context,
      builder: (context) => CalculatorDialog(isTablet: isTablet),
    );
  }
}

class CalculatorDialog extends StatefulWidget {
  final bool isTablet;
  
  const CalculatorDialog({super.key, required this.isTablet});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> with TickerProviderStateMixin {
  String _display = '0';
  String _operation = '';
  double _firstNumber = 0;
  double _secondNumber = 0;
  bool _waitingForOperand = false;
  
  // Memory functions
  double _memory = 0;
  bool _memoryIndicator = false;
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: widget.isTablet ? 450 : 350,
        height: widget.isTablet ? 650 : 550,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 10),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(8, 111, 222, 0.977),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calculate_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Professional Calculator',
                  style: TextStyle(
                    fontSize: widget.isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                const Spacer(),
                if (_memoryIndicator)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'M',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    foregroundColor: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_operation.isNotEmpty)
                    Text(
                      '$_firstNumber $_operation',
                      style: TextStyle(
                        fontSize: widget.isTablet ? 16 : 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  Text(
                    _display,
                    style: TextStyle(
                      fontSize: widget.isTablet ? 32 : 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Calculator Content
            Expanded(
              child: SingleChildScrollView(
                child: _buildUnifiedCalculator(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Unified Calculator
  Widget _buildUnifiedCalculator() {
    return Column(
      children: [
        // Memory functions row
        _buildButtonRow(['MC', 'MR', 'M+', 'M-']),
        const SizedBox(height: 6),
        
        // Scientific functions row 1
        _buildButtonRow(['π', 'e', '√', 'x²']),
        const SizedBox(height: 6),
        
        // Scientific functions row 2
        _buildButtonRow(['sin', 'cos', 'tan', 'log']),
        const SizedBox(height: 6),
        
        // Scientific functions row 3
        _buildButtonRow(['ln', '1/x', 'x!', '^']),
        const SizedBox(height: 6),
        
        // Basic operations row 1
        _buildButtonRow(['(', ')', 'C', '÷']),
        const SizedBox(height: 6),
        
        // Basic operations row 2
        _buildButtonRow(['7', '8', '9', '×']),
        const SizedBox(height: 6),
        
        // Basic operations row 3
        _buildButtonRow(['4', '5', '6', '-']),
        const SizedBox(height: 6),
        
        // Basic operations row 4
        _buildButtonRow(['1', '2', '3', '+']),
        const SizedBox(height: 6),
        
        // Basic operations row 5
        _buildButtonRow(['±', '0', '.', '='], isLastRow: true),
      ],
    );
  }

  // Unit Conversion Tab
  Widget _buildConversionCalculator() {
    return Column(
      children: [
        // Length conversions
        _buildConversionRow('Length', ['m', 'ft', 'in', 'cm']),
        const SizedBox(height: 6),
        
        // Area conversions
        _buildConversionRow('Area', ['m²', 'ft²', 'in²', 'cm²']),
        const SizedBox(height: 6),
        
        // Volume conversions
        _buildConversionRow('Volume', ['m³', 'ft³', 'L', 'gal']),
        const SizedBox(height: 6),
        
        // Weight conversions
        _buildConversionRow('Weight', ['kg', 'lb', 'oz', 'g']),
        const SizedBox(height: 6),
        
        // Temperature conversions
        _buildConversionRow('Temperature', ['°C', '°F', 'K', '°R']),
      ],
    );
  }

  // Inspection-specific Calculator Tab
  Widget _buildInspectionCalculator() {
    return Column(
      children: [
        // Area calculations
        _buildInspectionRow('Area', ['Rectangle', 'Circle', 'Triangle', 'Trapezoid']),
        const SizedBox(height: 6),
        
        // Volume calculations
        _buildInspectionRow('Volume', ['Box', 'Cylinder', 'Sphere', 'Cone']),
        const SizedBox(height: 6),
        
        // Percentage calculations
        _buildInspectionRow('Percentage', ['Defect %', 'Progress %', 'Quality %', 'Completion %']),
        const SizedBox(height: 6),
        
        // Ratio calculations
        _buildInspectionRow('Ratio', ['Aspect Ratio', 'Slope', 'Grade', 'Pitch']),
        const SizedBox(height: 6),
        
        // Material calculations
        _buildInspectionRow('Materials', ['Concrete', 'Steel', 'Wood', 'Paint']),
      ],
    );
  }

  Widget _buildButtonRow(List<String> buttons, {bool isLastRow = false}) {
    return Row(
      children: buttons.map((button) {
        if (isLastRow && button == '0') {
          // Make 0 button wider
          return Expanded(
            flex: 2,
            child: _buildCalculatorButton(button),
          );
        } else if (isLastRow && button == '.') {
          return Expanded(
            child: _buildCalculatorButton(button),
          );
        } else if (isLastRow && button == '=') {
          return Expanded(
            child: _buildCalculatorButton(button),
          );
        } else {
          return Expanded(
            child: _buildCalculatorButton(button),
          );
        }
      }).toList(),
    );
  }

  Widget _buildConversionRow(String category, List<String> units) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: TextStyle(
            fontSize: widget.isTablet ? 12 : 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: units.map((unit) => Expanded(
            child: _buildCalculatorButton(unit),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildInspectionRow(String category, List<String> functions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: TextStyle(
            fontSize: widget.isTablet ? 12 : 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: functions.map((function) => Expanded(
            child: _buildCalculatorButton(function),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildCalculatorButton(String text) {
    final bool isNumber = RegExp(r'[0-9]').hasMatch(text);
    final bool isOperator = ['+', '-', '×', '÷', '='].contains(text);
    final bool isMemory = ['MC', 'MR', 'M+', 'M-'].contains(text);
    final bool isSpecial = ['C', '±', '%'].contains(text);
    final bool isScientific = ['π', 'e', '√', 'x²', 'sin', 'cos', 'tan', 'log', 'ln', '1/x', 'x!', '^', '(', ')'].contains(text);
    final bool isDecimal = text == '.';

    Color backgroundColor;
    Color textColor;

    if (isNumber || isDecimal) {
      backgroundColor = Colors.white;
      textColor = const Color(0xFF1F2937);
    } else if (isOperator) {
      backgroundColor = const Color.fromRGBO(8, 111, 222, 0.977);
      textColor = Colors.white;
    } else if (isMemory) {
      backgroundColor = const Color(0xFF10B981);
      textColor = Colors.white;
    } else if (isScientific) {
      backgroundColor = const Color(0xFF8B5CF6);
      textColor = Colors.white;
    } else if (isSpecial) {
      backgroundColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF6B7280);
    } else {
      backgroundColor = Colors.white;
      textColor = const Color(0xFF1F2937);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: () => _onButtonPressed(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            vertical: widget.isTablet ? 12 : 10,
            horizontal: 6,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: widget.isTablet ? 18 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _onButtonPressed(String buttonText) {
    setState(() {
      if (RegExp(r'[0-9]').hasMatch(buttonText)) {
        _onNumberPressed(buttonText);
      } else if (buttonText == '.') {
        _onDecimalPressed();
      } else if (['+', '-', '×', '÷'].contains(buttonText)) {
        _onOperatorPressed(buttonText);
      } else if (buttonText == '=') {
        _onEqualsPressed();
      } else if (buttonText == 'C') {
        _onClearPressed();
      } else if (buttonText == '±') {
        _onSignPressed();
      } else if (buttonText == '%') {
        _onPercentPressed();
      } else if (['MC', 'MR', 'M+', 'M-'].contains(buttonText)) {
        _onMemoryPressed(buttonText);
      } else if (['π', 'e', '√', 'x²', 'sin', 'cos', 'tan', 'log', 'ln', '1/x', 'x!', '^'].contains(buttonText)) {
        _onScientificPressed(buttonText);
      } else if (['(', ')'].contains(buttonText)) {
        _onParenthesisPressed(buttonText);
      }
    });
  }

  void _onNumberPressed(String number) {
    if (_waitingForOperand) {
      _display = number;
      _waitingForOperand = false;
    } else {
      _display = _display == '0' ? number : _display + number;
    }
  }

  void _onDecimalPressed() {
    if (_waitingForOperand) {
      _display = '0.';
      _waitingForOperand = false;
    } else if (!_display.contains('.')) {
      _display += '.';
    }
  }

  void _onOperatorPressed(String operator) {
    if (_operation.isNotEmpty && !_waitingForOperand) {
      _onEqualsPressed();
    }

    _firstNumber = double.parse(_display);
    _operation = operator;
    _waitingForOperand = true;
  }

  void _onEqualsPressed() {
    if (_operation.isEmpty) return;

    _secondNumber = double.parse(_display);
    double result = 0;

    switch (_operation) {
      case '+':
        result = _firstNumber + _secondNumber;
        break;
      case '-':
        result = _firstNumber - _secondNumber;
        break;
      case '×':
        result = _firstNumber * _secondNumber;
        break;
      case '÷':
        if (_secondNumber != 0) {
          result = _firstNumber / _secondNumber;
        } else {
          _display = 'Error';
          return;
        }
        break;
    }

    _display = result % 1 == 0 ? result.toInt().toString() : result.toString();
    _operation = '';
    _waitingForOperand = true;
  }

  void _onClearPressed() {
    _display = '0';
    _operation = '';
    _firstNumber = 0;
    _secondNumber = 0;
    _waitingForOperand = false;
  }

  void _onSignPressed() {
    if (_display != '0') {
      if (_display.startsWith('-')) {
        _display = _display.substring(1);
      } else {
        _display = '-$_display';
      }
    }
  }

  void _onPercentPressed() {
    double number = double.parse(_display);
    _display = (number / 100).toString();
  }

  // Memory functions
  void _onMemoryPressed(String operation) {
    double currentValue = double.parse(_display);
    
    switch (operation) {
      case 'MC':
        _memory = 0;
        _memoryIndicator = false;
        break;
      case 'MR':
        _display = _memory.toString();
        _waitingForOperand = true;
        break;
      case 'M+':
        _memory += currentValue;
        _memoryIndicator = true;
        break;
      case 'M-':
        _memory -= currentValue;
        _memoryIndicator = true;
        break;
    }
  }

  // Scientific functions
  void _onScientificPressed(String function) {
    double value = double.parse(_display);
    double result = 0;
    
    switch (function) {
      case 'π':
        result = 3.14159265359;
        break;
      case 'e':
        result = 2.71828182846;
        break;
      case '√':
        result = value >= 0 ? sqrt(value) : 0;
        break;
      case 'x²':
        result = value * value;
        break;
      case 'sin':
        result = sin(value);
        break;
      case 'cos':
        result = cos(value);
        break;
      case 'tan':
        result = tan(value);
        break;
      case 'log':
        result = value > 0 ? log(value) / ln10 : 0;
        break;
      case 'ln':
        result = value > 0 ? log(value) : 0;
        break;
      case '1/x':
        result = value != 0 ? 1 / value : 0;
        break;
      case 'x!':
        result = _factorial(value.toInt());
        break;
      case '^':
        _operation = '^';
        _firstNumber = value;
        _waitingForOperand = true;
        return;
    }
    
    _display = result % 1 == 0 ? result.toInt().toString() : result.toString();
    _waitingForOperand = true;
  }

  // Parenthesis handling
  void _onParenthesisPressed(String parenthesis) {
    // Simple implementation - could be enhanced for complex expressions
    if (parenthesis == '(') {
      _display = '0';
      _waitingForOperand = true;
    }
  }

  // Helper functions
  double _factorial(int n) {
    if (n < 0) return 0;
    if (n == 0 || n == 1) return 1;
    double result = 1;
    for (int i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }
}
