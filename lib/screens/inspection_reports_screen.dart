import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/inspection.dart';
import '../services/hive_offline_database.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'inspection_form_screen.dart';

class InspectionReportsScreen extends StatefulWidget {
  const InspectionReportsScreen({super.key});

  @override
  State<InspectionReportsScreen> createState() => _InspectionReportsScreenState();
}

class _InspectionReportsScreenState extends State<InspectionReportsScreen> {
  List<Inspection> _inspections = [];
  bool _isLoading = true;
  User? _currentUser;
  String _searchQuery = '';
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    await _loadInspections();
  }

  Future<void> _loadUserData() async {
    try {
      print('Loading user data...');
      final user = await AuthService.getCurrentUser();
      print('User loaded: ${user?.id} (${user?.name})');
      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadInspections() async {
    try {
      setState(() {
        _isLoading = true;
      });

      print('Loading inspections...');
      print('Current user: ${_currentUser?.id} (${_currentUser?.name})');
      
      final inspections = HiveOfflineDatabase.getInspections();
      print('Total inspections found: ${inspections.length}');
      
      List<Inspection> userInspections;
      
      // If user is not authenticated, show all inspections
      if (_currentUser?.id == null) {
        print('No current user found, showing all inspections');
        userInspections = inspections;
      } else {
        // Filter inspections by current user
        userInspections = inspections.where((inspection) {
          final matches = inspection.userId == _currentUser?.id.toString();
          print('Inspection ${inspection.id}: userId=${inspection.userId}, currentUserId=${_currentUser?.id.toString()}, matches=$matches');
          return matches;
        }).toList();
        print('User-specific inspections: ${userInspections.length}');
      }

      // Sort by creation date (newest first)
      userInspections.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _inspections = userInspections;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading inspections: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Inspection> get _filteredInspections {
    List<Inspection> filtered = _inspections;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((inspection) {
        return inspection.scannedData.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               inspection.id.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by status
    if (_selectedStatus != 'All') {
      filtered = filtered.where((inspection) {
        if (_selectedStatus == 'Pending') {
          // Show inspections that have sections in progress
          final sectionStatuses = inspection.sectionStatus.values.toList();
          return sectionStatuses.contains('in_progress');
        } else if (_selectedStatus == 'Completed') {
          // Show inspections that are fully completed (no sections in progress)
          final sectionStatuses = inspection.sectionStatus.values.toList();
          return sectionStatuses.isNotEmpty && 
                 !sectionStatuses.contains('in_progress') &&
                 (sectionStatuses.contains('passed') || sectionStatuses.contains('not_passed'));
        }
        return true;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, isTablet),
            
            // Search and Filter Bar
            _buildSearchAndFilter(context, isTablet),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredInspections.isEmpty
                      ? _buildEmptyState(context, isTablet)
                      : _buildInspectionsList(context, isTablet),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inspection Reports',
                  style: TextStyle(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
            Text(
              _currentUser != null 
                  ? 'View your submitted inspections'
                  : 'View all submitted inspections',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: const Color(0xFF6B7280),
              ),
            ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
                ),
                child: Text(
                  '${_inspections.length}',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0EA5E9),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _loadInspections,
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F9FF),
                  foregroundColor: const Color(0xFF0EA5E9),
                  side: const BorderSide(color: Color(0xFF0EA5E9), width: 1),
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      color: Colors.white,
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search inspections...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 16 : 12,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filter Chips
          Row(
            children: [
              _buildFilterChip('All', _selectedStatus == 'All', () {
                setState(() {
                  _selectedStatus = 'All';
                });
              }, isTablet),
              const SizedBox(width: 8),
              _buildFilterChip('Pending', _selectedStatus == 'Pending', () {
                setState(() {
                  _selectedStatus = 'Pending';
                });
              }, isTablet),
              const SizedBox(width: 8),
              _buildFilterChip('Completed', _selectedStatus == 'Completed', () {
                setState(() {
                  _selectedStatus = 'Completed';
                });
              }, isTablet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, bool isTablet) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isTablet) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
              ),
              child: Icon(
                Icons.assessment_outlined,
                size: isTablet ? 64 : 48,
                color: const Color(0xFF0EA5E9),
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Text(
              'No Inspections Found',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF374151),
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              _selectedStatus == 'All'
                  ? 'You haven\'t submitted any inspections yet.'
                  : 'No inspections found with the selected filter.',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionsList(BuildContext context, bool isTablet) {
    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      itemCount: _filteredInspections.length,
      itemBuilder: (context, index) {
        final inspection = _filteredInspections[index];
        return _buildInspectionCard(inspection, isTablet);
      },
    );
  }

  Widget _buildInspectionCard(Inspection inspection, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _buildInspectionDetails(inspection, isTablet),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: inspection.isSynced 
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        inspection.isSynced 
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color: inspection.isSynced 
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        size: isTablet ? 20 : 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inspection #${inspection.id.substring(inspection.id.length - 8)}',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Created: ${_formatDateTime(inspection.createdAt)}',
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 10,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 12 : 8,
                            vertical: isTablet ? 6 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: inspection.isSynced 
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            inspection.isSynced ? 'Synced' : 'Pending',
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _showDeleteConfirmation(inspection, isTablet),
                          icon: const Icon(Icons.delete_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFFEF2F2),
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFECACA), width: 1),
                            padding: EdgeInsets.all(isTablet ? 8 : 6),
                          ),
                          tooltip: 'Delete Inspection',
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // QR Data
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Text(
                    inspection.scannedData,
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: const Color(0xFF374151),
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Stats Row
                Row(
                  children: [
                    _buildStatItem(
                      'Sections',
                      _getSelectedSectionsCount(inspection).toString(),
                      Icons.checklist_rounded,
                      const Color(0xFF3B82F6),
                      isTablet,
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    _buildStatItem(
                      'Photos',
                      inspection.imagePaths.length.toString(),
                      Icons.photo_camera_rounded,
                      const Color(0xFF10B981),
                      isTablet,
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    _buildStatItem(
                      'Videos',
                      inspection.videoPaths.length.toString(),
                      Icons.videocam_rounded,
                      const Color(0xFFEF4444),
                      isTablet,
                    ),
                    if (inspection.inspectionStartTime != null && inspection.inspectionEndTime != null) ...[
                      SizedBox(width: isTablet ? 16 : 12),
                      _buildStatItem(
                        'Duration',
                        _calculateDuration(inspection.inspectionStartTime!, inspection.inspectionEndTime!),
                        Icons.timer_rounded,
                        const Color(0xFF8B5CF6),
                        isTablet,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isTablet) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 8 : 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: isTablet ? 16 : 14,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _buildInspectionDetails(Inspection inspection, bool isTablet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.assessment_rounded,
                        color: Colors.white,
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
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${inspection.id.substring(inspection.id.length - 8)}',
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
                        horizontal: isTablet ? 10 : 8,
                        vertical: isTablet ? 4 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: inspection.isSynced 
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        inspection.isSynced ? 'Synced' : 'Pending',
                        style: TextStyle(
                          fontSize: isTablet ? 10 : 8,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        foregroundColor: const Color(0xFF6B7280),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Export Button
                      _buildExportButton(isTablet),
                      const SizedBox(height: 20),
                      
                      // QR Code Data
                      _buildSectionCard('QR Code Data', inspection.scannedData, Icons.qr_code_rounded, isTablet),
                      const SizedBox(height: 16),
                      
                      // Inspection Sections
                      _buildInspectionSections(inspection, isTablet),
                      const SizedBox(height: 16),
                      
                      // Section Status
                      if (inspection.sectionStatus.isNotEmpty) ...[
                        _buildSectionStatusCard(inspection, isTablet),
                        const SizedBox(height: 16),
                      ],
                      
                      // Location Data
                      if (inspection.latitude != null && inspection.longitude != null) ...[
                        _buildLocationCard(inspection, isTablet),
                        const SizedBox(height: 16),
                      ],
                      
                      // Media Data
                      if (inspection.imagePaths.isNotEmpty || inspection.videoPaths.isNotEmpty) ...[
                        _buildMediaCard(inspection, isTablet),
                        const SizedBox(height: 16),
                      ],
                      
                      // Timing Data
                      if (inspection.inspectionStartTime != null || inspection.inspectionEndTime != null) ...[
                        _buildTimingCard(inspection, isTablet),
                        const SizedBox(height: 16),
                      ],
                      
                      // Technical Details
                      _buildTechnicalDetails(inspection, isTablet),
                      
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      _buildActionButtons(inspection, isTablet),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Inspection inspection, bool isTablet) {
    // Determine if inspection is completed based on section status
    final sectionStatuses = inspection.sectionStatus.values.toList();
    final hasInProgress = sectionStatuses.contains('in_progress');
    final hasNotPassed = sectionStatuses.contains('not_passed');
    final hasPassed = sectionStatuses.contains('passed');
    
    // Check if inspection is fully completed (all sections have passed or not_passed status, NO in_progress)
    final isCompleted = sectionStatuses.isNotEmpty && 
                       !hasInProgress &&
                       (hasPassed || hasNotPassed);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_arrow_rounded, color: const Color(0xFF3B82F6), size: isTablet ? 20 : 18),
              const SizedBox(width: 8),
              Text(
                'Actions',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Action buttons row
          Row(
            children: [
              // Mark as Completed button (only show if not already completed)
              if (!isCompleted) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _markAsCompleted(inspection),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      'Mark as Completed',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 14 : 12,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              
              // Continue Inspection button (always show)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _continueInspection(inspection),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(
                    'Continue Inspection',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isTablet ? 14 : 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          
          // Status information
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted 
                      ? Icons.check_circle_rounded 
                      : hasInProgress 
                          ? Icons.hourglass_empty_rounded
                          : Icons.help_outline_rounded,
                  color: isCompleted 
                      ? const Color(0xFF10B981) 
                      : hasInProgress 
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF6B7280),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCompleted 
                        ? 'Inspection is completed'
                        : hasInProgress 
                            ? 'Inspection is in progress'
                            : 'Inspection has no sections',
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: isCompleted 
                          ? const Color(0xFF10B981) 
                          : hasInProgress 
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
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

  void _markAsCompleted(Inspection inspection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Mark as Completed'),
          ],
        ),
        content: const Text(
          'Are you sure you want to mark this inspection as completed? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmMarkAsCompleted(inspection);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
  }

  void _confirmMarkAsCompleted(Inspection inspection) async {
    try {
      // Update all in_progress sections to passed
      final updatedSectionStatus = Map<String, String>.from(inspection.sectionStatus);
      updatedSectionStatus.forEach((key, value) {
        if (value == 'in_progress') {
          updatedSectionStatus[key] = 'passed';
        }
      });
      
      // Create updated inspection
      final updatedInspection = Inspection(
        id: inspection.id,
        scannedData: inspection.scannedData,
        latitude: inspection.latitude,
        longitude: inspection.longitude,
        mechanicalRemarks: inspection.mechanicalRemarks,
        mechanicalAssessment: inspection.mechanicalAssessment,
        lineGradeRemarks: inspection.lineGradeRemarks,
        lineGradeAssessment: inspection.lineGradeAssessment,
        architecturalRemarks: inspection.architecturalRemarks,
        architecturalAssessment: inspection.architecturalAssessment,
        civilStructuralRemarks: inspection.civilStructuralRemarks,
        civilStructuralAssessment: inspection.civilStructuralAssessment,
        sanitaryPlumbingRemarks: inspection.sanitaryPlumbingRemarks,
        sanitaryPlumbingAssessment: inspection.sanitaryPlumbingAssessment,
        electricalElectronicsRemarks: inspection.electricalElectronicsRemarks,
        electricalElectronicsAssessment: inspection.electricalElectronicsAssessment,
        imagePaths: inspection.imagePaths,
        videoPaths: inspection.videoPaths,
        sectionImagePaths: inspection.sectionImagePaths,
        sectionVideoPaths: inspection.sectionVideoPaths,
        inspectionStartTime: inspection.inspectionStartTime,
        inspectionEndTime: inspection.inspectionEndTime ?? DateTime.now(),
        sectionStatus: updatedSectionStatus,
        isSynced: inspection.isSynced,
        createdAt: inspection.createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Save to Hive
      await HiveOfflineDatabase.saveInspection(updatedInspection);
      
      // Refresh the list
      _loadInspections();
      
      // Close the modal
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inspection marked as completed successfully!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking inspection as completed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _continueInspection(Inspection inspection) {
    // Close the modal first
    Navigator.of(context).pop();
    
    // Navigate to inspection form with existing data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionFormScreen(
          existingInspection: inspection,
          isEditing: true,
        ),
      ),
    );
  }

  Widget _buildExportButton(bool isTablet) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // Export functionality will be implemented later
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export functionality coming soon!'),
              backgroundColor: Color(0xFF3B82F6),
              duration: Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.download_rounded, color: Colors.white),
        label: Text(
          'Export Report',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 16 : 14,
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, String content, IconData icon, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF3B82F6), size: isTablet ? 20 : 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Text(
              content,
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: const Color(0xFF374151),
                fontFamily: title == 'QR Code Data' ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionSections(Inspection inspection, bool isTablet) {
    final sections = [
      {'name': 'Mechanical', 'remarks': inspection.mechanicalRemarks, 'assessment': inspection.mechanicalAssessment},
      {'name': 'Line and Grade', 'remarks': inspection.lineGradeRemarks, 'assessment': inspection.lineGradeAssessment},
      {'name': 'Architectural', 'remarks': inspection.architecturalRemarks, 'assessment': inspection.architecturalAssessment},
      {'name': 'Civil/Structural', 'remarks': inspection.civilStructuralRemarks, 'assessment': inspection.civilStructuralAssessment},
      {'name': 'Sanitary/Plumbing', 'remarks': inspection.sanitaryPlumbingRemarks, 'assessment': inspection.sanitaryPlumbingAssessment},
      {'name': 'Electrical/Electronics', 'remarks': inspection.electricalElectronicsRemarks, 'assessment': inspection.electricalElectronicsAssessment},
    ];

    // Filter out empty sections
    final filledSections = sections.where((section) => 
      section['remarks']!.isNotEmpty || section['assessment']!.isNotEmpty
    ).toList();

    if (filledSections.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 16 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rounded, color: const Color(0xFF3B82F6), size: isTablet ? 20 : 18),
                const SizedBox(width: 8),
                Text(
                  'Inspection Sections',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'No inspection sections were filled out.',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: const Color(0xFF6B7280),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: const Color(0xFF3B82F6), size: isTablet ? 20 : 18),
              const SizedBox(width: 8),
              Text(
                'Inspection Sections (${filledSections.length})',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...filledSections.map((section) => _buildSectionDetail(section['name']!, section['remarks']!, section['assessment']!, isTablet, inspection)).toList(),
        ],
      ),
    );
  }

  Widget _buildSectionDetail(String sectionName, String remarks, String assessment, bool isTablet, Inspection inspection) {
    // Get section-specific media
    final sectionImages = inspection.sectionImagePaths?[sectionName] ?? [];
    final sectionVideos = inspection.sectionVideoPaths?[sectionName] ?? [];
    
    // Check if this is Civil/Structural section for location display
    final showLocation = sectionName == 'Civil/Structural' && 
                        inspection.latitude != null && 
                        inspection.longitude != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isTablet ? 12 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sectionName,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
              // Add status indicator if available
              if (remarks.isNotEmpty || assessment.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 8 : 6,
                    vertical: isTablet ? 4 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981), width: 1),
                  ),
                  child: Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: isTablet ? 10 : 8,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (remarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Remarks:',
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              remarks,
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                color: const Color(0xFF374151),
              ),
            ),
          ],
          if (assessment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Assessment:',
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              assessment,
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                color: const Color(0xFF374151),
              ),
            ),
          ],
          
          // Section-specific media
          if (sectionImages.isNotEmpty || sectionVideos.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSectionMedia(sectionImages, sectionVideos, sectionName, isTablet),
          ],
          
          // Section-specific location (only for Civil/Structural)
          if (showLocation) ...[
            const SizedBox(height: 8),
            _buildSectionLocation(inspection, isTablet),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionMedia(List<String> images, List<String> videos, String sectionName, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 12 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_rounded, color: const Color(0xFF0EA5E9), size: isTablet ? 16 : 14),
              const SizedBox(width: 6),
              Text(
                'Media for $sectionName',
                style: TextStyle(
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0EA5E9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (images.isNotEmpty) ...[
            Text(
              'Images (${images.length}):',
              style: TextStyle(
                fontSize: isTablet ? 11 : 9,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: images.map((imagePath) => Container(
                width: isTablet ? 60 : 50,
                height: isTablet ? 60 : 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                      );
                    },
                  ),
                ),
              )).toList(),
            ),
          ],
          if (videos.isNotEmpty) ...[
            if (images.isNotEmpty) const SizedBox(height: 8),
            Text(
              'Videos (${videos.length}):',
              style: TextStyle(
                fontSize: isTablet ? 11 : 9,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(height: 4),
            ...videos.map((videoPath) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_arrow, color: const Color(0xFF0EA5E9), size: isTablet ? 16 : 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Video ${videos.indexOf(videoPath) + 1}',
                      style: TextStyle(
                        fontSize: isTablet ? 11 : 9,
                        color: const Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLocation(Inspection inspection, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 12 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: const Color(0xFF0EA5E9), size: isTablet ? 16 : 14),
              const SizedBox(width: 6),
              Text(
                'Civil/Structural Location Details',
                style: TextStyle(
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0EA5E9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Address Information
          FutureBuilder<String?>(
            future: _getAddressForLocation(inspection.latitude!, inspection.longitude!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading address...',
                        style: TextStyle(
                          fontSize: isTablet ? 11 : 9,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              if (snapshot.hasData && snapshot.data != null) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place_rounded, color: const Color(0xFF0EA5E9), size: isTablet ? 14 : 12),
                          const SizedBox(width: 6),
                          Text(
                            'Complete Address:',
                            style: TextStyle(
                              fontSize: isTablet ? 11 : 9,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.data!,
                        style: TextStyle(
                          fontSize: isTablet ? 11 : 9,
                          color: const Color(0xFF0EA5E9),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              // Fallback if address loading fails
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off_rounded, color: Colors.orange, size: isTablet ? 14 : 12),
                    const SizedBox(width: 6),
                    Text(
                      'Address not available',
                      style: TextStyle(
                        fontSize: isTablet ? 11 : 9,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // Coordinates in a more readable format
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GPS Coordinates:',
                  style: TextStyle(
                    fontSize: isTablet ? 11 : 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Latitude: ${inspection.latitude!.toStringAsFixed(8)}°',
                  style: TextStyle(
                    fontSize: isTablet ? 11 : 9,
                    color: const Color(0xFF0EA5E9),
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Longitude: ${inspection.longitude!.toStringAsFixed(8)}°',
                  style: TextStyle(
                    fontSize: isTablet ? 11 : 9,
                    color: const Color(0xFF0EA5E9),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Action buttons for location
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Copy coordinates to clipboard
                    final coords = '${inspection.latitude!.toStringAsFixed(8)}, ${inspection.longitude!.toStringAsFixed(8)}';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Coordinates copied: $coords'),
                        backgroundColor: const Color(0xFF0EA5E9),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(
                    'Copy Coords',
                    style: TextStyle(fontSize: isTablet ? 10 : 8),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 8 : 6,
                      vertical: isTablet ? 6 : 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openGoogleMaps(inspection.latitude!, inspection.longitude!),
                  icon: const Icon(Icons.map_rounded, size: 14),
                  label: Text(
                    'Open Maps',
                    style: TextStyle(fontSize: isTablet ? 10 : 8),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0EA5E9),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 8 : 6,
                      vertical: isTablet ? 6 : 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0xFF0EA5E9), width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _getAddressForLocation(double lat, double lng) async {
    try {
      // Use OpenStreetMap Nominatim API for reverse geocoding
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1'),
        headers: {
          'User-Agent': 'OBO-Mobile/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['address'] != null) {
          final address = data['address'];
          
          // Build a comprehensive address string
          List<String> addressParts = [];
          
          // Add specific address components in order of specificity
          if (address['house_number'] != null) {
            addressParts.add(address['house_number']);
          }
          if (address['road'] != null) {
            addressParts.add(address['road']);
          }
          if (address['suburb'] != null) {
            addressParts.add(address['suburb']);
          }
          if (address['neighbourhood'] != null && address['neighbourhood'] != address['suburb']) {
            addressParts.add(address['neighbourhood']);
          }
          if (address['village'] != null) {
            addressParts.add(address['village']);
          }
          if (address['city'] != null) {
            addressParts.add(address['city']);
          }
          if (address['town'] != null && address['town'] != address['city']) {
            addressParts.add(address['town']);
          }
          if (address['municipality'] != null) {
            addressParts.add(address['municipality']);
          }
          if (address['county'] != null) {
            addressParts.add(address['county']);
          }
          if (address['state'] != null) {
            addressParts.add(address['state']);
          }
          if (address['postcode'] != null) {
            addressParts.add(address['postcode']);
          }
          if (address['country'] != null) {
            addressParts.add(address['country']);
          }
          
          // Join all parts with commas
          String fullAddress = addressParts.join(', ');
          
          // If we have a good address, return it
          if (fullAddress.isNotEmpty) {
            return fullAddress;
          }
          
          // Fallback to display_name if available
          if (data['display_name'] != null) {
            return data['display_name'];
          }
        }
      }
    } catch (e) {
      print('Failed to get address: $e');
    }
    
    return null;
  }

  void _openGoogleMaps(double lat, double lng) async {
    // Show loading message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening Google Maps...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Create Google Maps URL
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    
    try {
      // Platform-specific handling
      if (kIsWeb) {
        // For web platform, use window.open equivalent
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // For mobile platforms, try different approaches
        bool launched = false;
        
        // Try Android intent first
        try {
          final androidUrl = 'geo:$lat,$lng?q=$lat,$lng';
          if (await canLaunchUrl(Uri.parse(androidUrl))) {
            await launchUrl(Uri.parse(androidUrl));
            launched = true;
          }
        } catch (e) {
          print('Android geo: failed: $e');
        }
        
        // Try iOS Google Maps app
        if (!launched) {
          try {
            final iosUrl = 'comgooglemaps://?q=$lat,$lng';
            if (await canLaunchUrl(Uri.parse(iosUrl))) {
              await launchUrl(Uri.parse(iosUrl));
              launched = true;
            }
          } catch (e) {
            print('iOS Google Maps failed: $e');
          }
        }
        
        // Fallback to web URL
        if (!launched) {
          if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
            await launchUrl(
              Uri.parse(googleMapsUrl),
              mode: LaunchMode.externalApplication,
            );
            launched = true;
          }
        }
        
        // If all methods failed, show dialog
        if (!launched) {
          _showGoogleMapsDialog(googleMapsUrl, lat, lng);
        }
      }
    } catch (e) {
      print('Google Maps error: $e');
      // Show dialog as fallback
      _showGoogleMapsDialog(googleMapsUrl, lat, lng);
    }
  }
  
  void _showGoogleMapsDialog(String googleMapsUrl, double lat, double lng) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.map, color: Color(0xFF4285F4)),
              SizedBox(width: 8),
              Text('Open in Google Maps'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cannot open Google Maps automatically. Please copy this link:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: SelectableText(
                  googleMapsUrl,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Coordinates: $lat, $lng',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildLocationCard(Inspection inspection, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: const Color(0xFF3B82F6), size: isTablet ? 20 : 18),
              const SizedBox(width: 8),
              Text(
                'Location Data',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coordinates:',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Latitude: ${inspection.latitude!.toStringAsFixed(8)}',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: const Color(0xFF0EA5E9),
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Longitude: ${inspection.longitude!.toStringAsFixed(8)}',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: const Color(0xFF0EA5E9),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(Inspection inspection, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_rounded, color: const Color(0xFF3B82F6), size: isTablet ? 20 : 18),
              const SizedBox(width: 8),
              Text(
                'Media Files',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (inspection.imagePaths.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.photo_rounded, color: const Color(0xFF10B981), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Photos (${inspection.imagePaths.length})',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...inspection.imagePaths.map((path) => Text(
                    '• $path',
                    style: TextStyle(
                      fontSize: isTablet ? 10 : 8,
                      color: const Color(0xFF10B981),
                      fontFamily: 'monospace',
                    ),
                  )).toList(),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (inspection.videoPaths.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.videocam_rounded, color: const Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Videos (${inspection.videoPaths.length})',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...inspection.videoPaths.map((path) => Text(
                    '• $path',
                    style: TextStyle(
                      fontSize: isTablet ? 10 : 8,
                      color: const Color(0xFFEF4444),
                      fontFamily: 'monospace',
                    ),
                  )).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimingCard(Inspection inspection, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: const Color(0xFF3B82F6), size: isTablet ? 20 : 18),
              const SizedBox(width: 8),
              Text(
                'Inspection Timing',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (inspection.inspectionStartTime != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_arrow_rounded, color: const Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Start: ${_formatDateTime(inspection.inspectionStartTime!)}',
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (inspection.inspectionEndTime != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.stop_rounded, color: const Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'End: ${_formatDateTime(inspection.inspectionEndTime!)}',
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (inspection.inspectionStartTime != null && inspection.inspectionEndTime != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF8B5CF6), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_rounded, color: const Color(0xFF8B5CF6), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${_calculateDuration(inspection.inspectionStartTime!, inspection.inspectionEndTime!)}',
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: const Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w500,
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


  Widget _buildTechnicalDetails(Inspection inspection, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_rounded, color: const Color(0xFF3B82F6), size: isTablet ? 20 : 18),
              const SizedBox(width: 8),
              Text(
                'Technical Details',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Inspection ID', inspection.id, Icons.fingerprint_rounded, isTablet),
          const SizedBox(height: 6),
          _buildDetailRow('Created At', _formatDateTime(inspection.createdAt), Icons.schedule_rounded, isTablet),
          const SizedBox(height: 6),
          _buildDetailRow('Updated At', _formatDateTime(inspection.updatedAt), Icons.update_rounded, isTablet),
          const SizedBox(height: 6),
          _buildDetailRow('User ID', inspection.userId ?? 'N/A', Icons.person_rounded, isTablet),
          const SizedBox(height: 6),
          _buildDetailRow('Sync Status', inspection.isSynced ? 'Synced' : 'Pending', inspection.isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, isTablet),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isTablet) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: isTablet ? 16 : 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isTablet ? 10 : 8,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: const Color(0xFF1F2937),
                    fontFamily: label == 'Inspection ID' ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionStatusCard(Inspection inspection, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: const Color(0xFF3B82F6), size: isTablet ? 20 : 18),
              const SizedBox(width: 8),
              Text(
                'Section Status',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...inspection.sectionStatus.entries.map((entry) => _buildStatusItem(entry.key, entry.value, isTablet)).toList(),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String sectionName, String status, bool isTablet) {
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'not_passed':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.close_rounded;
        break;
      case 'in_progress':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case 'passed':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = const Color(0xFF6B7280);
        statusIcon = Icons.help_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isTablet ? 10 : 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: isTablet ? 16 : 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sectionName,
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 8 : 6,
              vertical: isTablet ? 4 : 2,
            ),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                fontSize: isTablet ? 10 : 8,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
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

  void _showDeleteConfirmation(Inspection inspection, bool isTablet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_rounded,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Inspection',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this inspection?',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inspection Details:',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${inspection.id.substring(inspection.id.length - 8)}',
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: const Color(0xFF6B7280),
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'Created: ${_formatDateTime(inspection.createdAt)}',
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  if (inspection.imagePaths.isNotEmpty || inspection.videoPaths.isNotEmpty) ...[
                    Text(
                      'Media: ${inspection.imagePaths.length} photos, ${inspection.videoPaths.length} videos',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFDC2626),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: const Color(0xFFDC2626),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 10,
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _deleteInspection(inspection);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInspection(Inspection inspection) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Delete from database
      await HiveOfflineDatabase.deleteInspection(inspection.id);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Refresh the inspections list
      await _loadInspections();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Inspection deleted successfully'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete inspection: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}
