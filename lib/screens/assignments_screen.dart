import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/connectivity_service.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Assignment> _assignments = [];
  AssignmentStatistics? _statistics;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isOffline = false;
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          _statistics = response.data!.statistics;
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

  Future<void> _loadAssignmentsByStatus(String status) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await AssignmentService.getAssignments(status: status);
      
      if (response.success && response.data != null) {
        setState(() {
          _assignments = response.data!.assignments;
          _statistics = response.data!.statistics;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0E5EC),
              Color(0xFFF0F4F8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E5EC),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFA3B1C6),
                            offset: Offset(4, 4),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-4, -4),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(25),
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'Assigned Inspections',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          if (_isOffline) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'OFFLINE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E5EC),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFA3B1C6),
                            offset: Offset(4, 4),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-4, -4),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(25),
                          onTap: _loadAssignments,
                          child: const Icon(
                            Icons.refresh,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Statistics Cards
              if (_statistics != null) _buildStatisticsCards(),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E5EC),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFA3B1C6),
                      offset: Offset(4, 4),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-4, -4),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF4A5568),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF4A5568),
                  onTap: (index) {
                    switch (index) {
                      case 0:
                        _loadAssignments();
                        break;
                      case 1:
                        _loadAssignmentsByStatus('assigned');
                        break;
                      case 2:
                        _loadAssignmentsByStatus('in_progress');
                        break;
                      case 3:
                        _loadAssignmentsByStatus('completed');
                        break;
                    }
                  },
                  tabs: [
                    Tab(text: 'All (${_statistics?.totalAssignments ?? 0})'),
                    Tab(text: 'Pending (${_statistics?.pendingAssignments ?? 0})'),
                    Tab(text: 'Progress (${_statistics?.inProgressAssignments ?? 0})'),
                    Tab(text: 'Done (${_statistics?.completedAssignments ?? 0})'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage.isNotEmpty
                        ? _buildErrorWidget()
                        : _assignments.isEmpty
                            ? _buildEmptyWidget()
                            : _buildAssignmentsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatCard('Total', _statistics!.totalAssignments, const Color(0xFF4A5568)),
          const SizedBox(width: 12),
          _buildStatCard('Pending', _statistics!.pendingAssignments, const Color(0xFFFFA500)),
          const SizedBox(width: 12),
          _buildStatCard('In Progress', _statistics!.inProgressAssignments, const Color(0xFF007BFF)),
          const SizedBox(width: 12),
          _buildStatCard('Completed', _statistics!.completedAssignments, const Color(0xFF28A745)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E5EC),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFA3B1C6),
            offset: Offset(4, 4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4A5568),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Color(0xFFDC3545),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading assignments',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF718096),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadAssignments,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A5568),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Color(0xFF718096),
          ),
          const SizedBox(height: 16),
          const Text(
            'No assignments found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You don\'t have any assigned inspections yet.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF718096),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final assignment = _assignments[index];
        return _buildAssignmentCard(assignment);
      },
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E5EC),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFA3B1C6),
            offset: Offset(6, 6),
            blurRadius: 12,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-6, -6),
            blurRadius: 12,
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(int.parse(assignment.statusColor.replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  assignment.statusDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Business ID
          _buildInfoRow('Business ID', assignment.businessId),
          
          // Department
          _buildInfoRow('Department', assignment.departmentName),
          
          // Address
          if (assignment.businessAddress != null && assignment.businessAddress!.isNotEmpty)
            _buildInfoRow('Address', assignment.businessAddress!),
          
          // Inspection Date
          if (assignment.inspectionDate != null)
            _buildInfoRow('Inspection Date', assignment.inspectionDate!),
          
          // Assigned Date
          _buildInfoRow('Assigned Date', assignment.assignedAt),
          
          // Assigned By
          if (assignment.assignedByName != null)
            _buildInfoRow('Assigned By', assignment.assignedByName!),
          
          // Notes
          if (assignment.assignmentNotes != null && assignment.assignmentNotes!.isNotEmpty)
            _buildInfoRow('Notes', assignment.assignmentNotes!),
          
          const SizedBox(height: 16),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Navigate to assignment details
                _showAssignmentDetails(assignment);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A5568),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF718096),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2D3748),
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
              _buildInfoRow('Business ID', assignment.businessId),
              _buildInfoRow('Department', assignment.departmentName),
              if (assignment.businessAddress != null && assignment.businessAddress!.isNotEmpty)
                _buildInfoRow('Address', assignment.businessAddress!),
              if (assignment.inspectionDate != null)
                _buildInfoRow('Inspection Date', assignment.inspectionDate!),
              _buildInfoRow('Status', assignment.statusDisplayName),
              _buildInfoRow('Assigned Date', assignment.assignedAt),
              if (assignment.assignedByName != null)
                _buildInfoRow('Assigned By', assignment.assignedByName!),
              if (assignment.assignmentNotes != null && assignment.assignmentNotes!.isNotEmpty)
                _buildInfoRow('Notes', assignment.assignmentNotes!),
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
