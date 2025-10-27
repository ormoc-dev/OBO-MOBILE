import 'package:flutter/material.dart';
import '../models/inspection.dart';
import '../services/hive_offline_database.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

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
        return inspection.isSynced == (_selectedStatus == 'Synced');
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
              _buildFilterChip('Synced', _selectedStatus == 'Synced', () {
                setState(() {
                  _selectedStatus = 'Synced';
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
            SizedBox(height: isTablet ? 24 : 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Start New Inspection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 20,
                  vertical: isTablet ? 16 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
        borderRadius: BorderRadius.circular(16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showInspectionDetails(inspection, isTablet),
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
          mainAxisAlignment: MainAxisAlignment.center,
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

  void _showInspectionDetails(Inspection inspection, bool isTablet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFE2E8F0),
                offset: Offset(0, -4),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 16),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.assessment_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inspection Report',
                            style: TextStyle(
                              fontSize: isTablet ? 22 : 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${inspection.id.substring(inspection.id.length - 8)}',
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
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
                        color: inspection.isSynced 
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            inspection.isSynced 
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_off_rounded,
                            color: Colors.white,
                            size: isTablet ? 16 : 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            inspection.isSynced ? 'Synced' : 'Pending',
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
                      ),
                      tooltip: 'Delete Inspection',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        foregroundColor: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(isTablet ? 24 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview Section
                      _buildSectionHeader('Overview', Icons.info_outline_rounded, isTablet),
                      const SizedBox(height: 16),
                      _buildOverviewCards(inspection, isTablet),
                      
                      const SizedBox(height: 24),
                      
                      // Timing Section
                      if (inspection.inspectionStartTime != null || inspection.inspectionEndTime != null) ...[
                        _buildSectionHeader('Timing', Icons.access_time_rounded, isTablet),
                        const SizedBox(height: 16),
                        _buildTimingCards(inspection, isTablet),
                        const SizedBox(height: 24),
                      ],
                      
                      // Media Section
                      if (inspection.imagePaths.isNotEmpty || inspection.videoPaths.isNotEmpty) ...[
                        _buildSectionHeader('Media', Icons.photo_camera_rounded, isTablet),
                        const SizedBox(height: 16),
                        _buildMediaCards(inspection, isTablet),
                        const SizedBox(height: 24),
                      ],
                      
                      // Technical Details
                      _buildSectionHeader('Technical Details', Icons.settings_rounded, isTablet),
                      const SizedBox(height: 16),
                      _buildTechnicalDetails(inspection, isTablet),
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

  Widget _buildSectionHeader(String title, IconData icon, bool isTablet) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF3B82F6),
            size: isTablet ? 20 : 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCards(Inspection inspection, bool isTablet) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                'QR Code',
                inspection.scannedData,
                Icons.qr_code_rounded,
                const Color(0xFF10B981),
                isTablet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                'Sections',
                _getSelectedSectionsCount(inspection).toString(),
                Icons.checklist_rounded,
                const Color(0xFF3B82F6),
                isTablet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                'Created',
                _formatDateTime(inspection.createdAt),
                Icons.schedule_rounded,
                const Color(0xFF6B7280),
                isTablet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                'Status',
                inspection.isSynced ? 'Synced' : 'Pending',
                inspection.isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                inspection.isSynced ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                isTablet,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimingCards(Inspection inspection, bool isTablet) {
    return Column(
      children: [
        if (inspection.inspectionStartTime != null) ...[
          _buildTimingCard('Start Time', _formatDateTime(inspection.inspectionStartTime!), Icons.play_arrow_rounded, const Color(0xFF10B981), isTablet),
          const SizedBox(height: 12),
        ],
        if (inspection.inspectionEndTime != null) ...[
          _buildTimingCard('End Time', _formatDateTime(inspection.inspectionEndTime!), Icons.stop_rounded, const Color(0xFFEF4444), isTablet),
          const SizedBox(height: 12),
        ],
        if (inspection.inspectionStartTime != null && inspection.inspectionEndTime != null) ...[
          _buildTimingCard('Duration', _calculateDuration(inspection.inspectionStartTime!, inspection.inspectionEndTime!), Icons.timer_rounded, const Color(0xFF8B5CF6), isTablet),
        ],
      ],
    );
  }

  Widget _buildMediaCards(Inspection inspection, bool isTablet) {
    return Column(
      children: [
        if (inspection.imagePaths.isNotEmpty) ...[
          _buildMediaCard('Photos', '${inspection.imagePaths.length} images captured', Icons.photo_camera_rounded, const Color(0xFF10B981), isTablet),
          const SizedBox(height: 12),
        ],
        if (inspection.videoPaths.isNotEmpty) ...[
          _buildMediaCard('Videos', '${inspection.videoPaths.length} videos captured', Icons.videocam_rounded, const Color(0xFFEF4444), isTablet),
        ],
      ],
    );
  }

  Widget _buildTechnicalDetails(Inspection inspection, bool isTablet) {
    return Column(
      children: [
        _buildDetailCard('Inspection ID', inspection.id, Icons.fingerprint_rounded, isTablet),
        const SizedBox(height: 12),
        _buildDetailCard('Updated At', _formatDateTime(inspection.updatedAt), Icons.update_rounded, isTablet),
        if (inspection.latitude != null && inspection.longitude != null) ...[
          const SizedBox(height: 12),
          _buildDetailCard('Location', '${inspection.latitude!.toStringAsFixed(4)}, ${inspection.longitude!.toStringAsFixed(4)}', Icons.location_on_rounded, isTablet),
        ],
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            offset: Offset(0, 1),
            blurRadius: 3,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isTablet ? 18 : 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTimingCard(String title, String value, IconData icon, Color color, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isTablet ? 20 : 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(String title, String value, IconData icon, Color color, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isTablet ? 20 : 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: isTablet ? 18 : 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1F2937),
                    fontFamily: title == 'Inspection ID' ? 'monospace' : null,
                  ),
                ),
              ],
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
