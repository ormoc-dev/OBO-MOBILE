import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/connectivity_service.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  List<Assignment> _assignments = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isOffline = false;
  String _searchQuery = '';
  String _selectedStatus = 'All';
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _loadAssignments();
    
    // Listen for connectivity changes
    _connectivityService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isOffline = !isConnected;
        });
        
        // Auto-refresh when connection is restored
        if (isConnected) {
          _loadAssignments();
        }
      }
    });
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await AssignmentService.getAssignments();
      
      if (response.success && response.data != null) {
        setState(() {
          _assignments = response.data!.assignments;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Assignment> get _filteredAssignments {
    List<Assignment> filtered = _assignments;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((assignment) {
        return assignment.businessName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               assignment.businessId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               assignment.departmentName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by status
    if (_selectedStatus != 'All') {
      filtered = filtered.where((assignment) {
        switch (_selectedStatus) {
          case 'Pending':
            return assignment.statusDisplayName.toLowerCase() == 'assigned';
          case 'Progress':
            return assignment.statusDisplayName.toLowerCase() == 'in progress';
          case 'Done':
            return assignment.statusDisplayName.toLowerCase() == 'completed';
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > 768;
    final isDesktop = screenWidth > 1024;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Clean Header
            _buildCleanHeader(context, isTablet),
            
            const SizedBox(height: 20),

            // Search and Filter Bar
            _buildSearchAndFilter(context, isTablet),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingWidget()
                  : _errorMessage.isNotEmpty
                      ? _buildErrorWidget()
                      : _filteredAssignments.isEmpty
                          ? _buildEmptyWidget()
                          : _buildAssignmentsList(isTablet, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  // Clean Modern UI Methods
  Widget _buildCleanHeader(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24.0 : 16.0,
        vertical: isTablet ? 20.0 : 16.0,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            offset: Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          
          
          SizedBox(width: isTablet ? 20 : 16),
          
          // Title and Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned Inspections',
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                if (_isOffline) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'OFFLINE',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Refresh Button
          IconButton(
            onPressed: _loadAssignments,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF2563EB),
            ),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
              hintText: 'Search assignments...',
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
              _buildFilterChip('Progress', _selectedStatus == 'Progress', () {
                setState(() {
                  _selectedStatus = 'Progress';
                });
              }, isTablet),
              const SizedBox(width: 8),
              _buildFilterChip('Done', _selectedStatus == 'Done', () {
                setState(() {
                  _selectedStatus = 'Done';
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

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading assignments...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              offset: Offset(0, 2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Error loading assignments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAssignments,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              offset: Offset(0, 2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No assignments found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You don\'t have any assigned inspections yet.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsList(bool isTablet, bool isDesktop) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      itemCount: _filteredAssignments.length,
      itemBuilder: (context, index) {
        final assignment = _filteredAssignments[index];
        return _buildAssignmentCard(assignment, isTablet);
      },
    );
  }

  Widget _buildAssignmentCard(Assignment assignment, bool isTablet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            offset: Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment.businessName,
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(int.parse(assignment.statusColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(int.parse(assignment.statusColor.replaceFirst('#', '0xFF'))),
                    width: 1,
                  ),
                ),
                child: Text(
                  assignment.statusDisplayName,
                  style: TextStyle(
                    color: Color(int.parse(assignment.statusColor.replaceFirst('#', '0xFF'))),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Assignment details
          _buildInfoRow('Business ID', assignment.businessId, isTablet),
          _buildInfoRow('Department', assignment.departmentName, isTablet),
          
          if (assignment.businessAddress != null && assignment.businessAddress!.isNotEmpty)
            _buildInfoRow('Address', assignment.businessAddress!, isTablet),
          
          if (assignment.inspectionDate != null)
            _buildInfoRow('Inspection Date', assignment.inspectionDate!, isTablet),
          
          _buildInfoRow('Assigned Date', assignment.assignedAt, isTablet),
          
          if (assignment.assignedByName != null)
            _buildInfoRow('Assigned By', assignment.assignedByName!, isTablet),
          
          if (assignment.assignmentNotes != null && assignment.assignmentNotes!.isNotEmpty)
            _buildInfoRow('Notes', assignment.assignmentNotes!, isTablet),
          
          const SizedBox(height: 20),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showAssignmentDetails(assignment);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'View Details',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isTablet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isTablet ? 120 : 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignmentDetails(Assignment assignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(assignment.businessName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Business ID', assignment.businessId, false),
              _buildInfoRow('Department', assignment.departmentName, false),
              if (assignment.businessAddress != null && assignment.businessAddress!.isNotEmpty)
                _buildInfoRow('Address', assignment.businessAddress!, false),
              if (assignment.inspectionDate != null)
                _buildInfoRow('Inspection Date', assignment.inspectionDate!, false),
              _buildInfoRow('Status', assignment.statusDisplayName, false),
              _buildInfoRow('Assigned Date', assignment.assignedAt, false),
              if (assignment.assignedByName != null)
                _buildInfoRow('Assigned By', assignment.assignedByName!, false),
              if (assignment.assignmentNotes != null && assignment.assignmentNotes!.isNotEmpty)
                _buildInfoRow('Notes', assignment.assignmentNotes!, false),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
