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
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final orientation = MediaQuery.of(context).orientation;
    
    // Enhanced responsive breakpoints
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
    // Dynamic scaling
    final double baseHeight = isLandscape ? 600.0 : 800.0;
    final double scale = (screenHeight / baseHeight).clamp(0.6, 1.3);
    final double smallScreenScale = isVerySmallScreen ? 0.8 : 1.0;
    final double finalScale = scale * smallScreenScale;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC), // Clean white
              Color(0xFFF1F5F9), // Light gray
              Color(0xFFE2E8F0), // Slightly darker gray
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
          children: [
            // Neumorphic Header
            _buildNeumorphicHeader(context, isTablet),
            
            const SizedBox(height: 16),

            // Statistics Cards
            if (_statistics != null) _buildNeumorphicStatisticsCards(isTablet),

            const SizedBox(height: 16),

            // Neumorphic Tab Bar
            _buildNeumorphicTabBar(isTablet),

            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? _buildNeumorphicErrorWidget()
                      : _assignments.isEmpty
                          ? _buildNeumorphicEmptyWidget()
                          : _buildNeumorphicAssignmentsList(),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // Neumorphic UI Methods
  Widget _buildNeumorphicHeader(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 32.0 : 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            offset: Offset(0, 4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 50 : 45,
            height: isTablet ? 50 : 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isTablet ? 25 : 22.5),
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
                borderRadius: BorderRadius.circular(isTablet ? 25 : 22.5),
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: const Color.fromRGBO(8, 111, 222, 0.977),
                  size: isTablet ? 24 : 20,
                ),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Inspections',
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      if (_isOffline) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 1),
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
                Container(
                  width: isTablet ? 50 : 45,
                  height: isTablet ? 50 : 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isTablet ? 25 : 22.5),
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
                      borderRadius: BorderRadius.circular(isTablet ? 25 : 22.5),
                      onTap: _loadAssignments,
                      child: Icon(
                        Icons.refresh_rounded,
                        color: const Color.fromRGBO(8, 111, 222, 0.977),
                        size: isTablet ? 24 : 20,
                      ),
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

  Widget _buildNeumorphicStatisticsCards(bool isTablet) {
    return Container(
      height: isTablet ? 110 : 90,
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 32.0 : 16.0),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildNeumorphicStatCard('Total', _statistics!.totalAssignments, const Color(0xFF4A5568), isTablet),
          SizedBox(width: isTablet ? 16 : 12),
          _buildNeumorphicStatCard('Pending', _statistics!.pendingAssignments, const Color(0xFFF59E0B), isTablet),
          SizedBox(width: isTablet ? 16 : 12),
          _buildNeumorphicStatCard('Progress', _statistics!.inProgressAssignments, const Color(0xFF3B82F6), isTablet),
          SizedBox(width: isTablet ? 16 : 12),
          _buildNeumorphicStatCard('Done', _statistics!.completedAssignments, const Color(0xFF10B981), isTablet),
        ],
      ),
    );
  }

  Widget _buildNeumorphicStatCard(String title, int count, Color color, bool isTablet) {
    return Container(
      width: isTablet ? 120 : 100,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 10 : 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          SizedBox(height: isTablet ? 6 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isTablet ? 12 : 10,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNeumorphicTabBar(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 32.0 : 16.0),
      padding: EdgeInsets.all(isTablet ? 6 : 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
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
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
              color: const Color.fromRGBO(8, 111, 222, 0.977),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFE2E8F0),
              offset: Offset(0, 2),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF6B7280),
        labelStyle: TextStyle(
          fontSize: isTablet ? 14 : 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: isTablet ? 14 : 12,
          fontWeight: FontWeight.w500,
        ),
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
    );
  }

  Widget _buildNeumorphicErrorWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFE0E5EC),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFA3B1C6),
              offset: Offset(8, 8),
              blurRadius: 16,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-8, -8),
              blurRadius: 16,
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
                color: const Color(0xFFE0E5EC),
                borderRadius: BorderRadius.circular(16),
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
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
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
              child: ElevatedButton(
                onPressed: _loadAssignments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Color(0xFF4A5568),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicEmptyWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFE0E5EC),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFA3B1C6),
              offset: Offset(8, 8),
              blurRadius: 16,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-8, -8),
              blurRadius: 16,
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
                color: const Color(0xFFE0E5EC),
                borderRadius: BorderRadius.circular(16),
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
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No assignments found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You don\'t have any assigned inspections yet.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicAssignmentsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final assignment = _assignments[index];
        return _buildNeumorphicAssignmentCard(assignment);
      },
    );
  }

  Widget _buildNeumorphicAssignmentCard(Assignment assignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            offset: Offset(0, 4),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
          
          // Business ID
          _buildNeumorphicInfoRow('Business ID', assignment.businessId),
          
          // Department
          _buildNeumorphicInfoRow('Department', assignment.departmentName),
          
          // Address
          if (assignment.businessAddress != null && assignment.businessAddress!.isNotEmpty)
            _buildNeumorphicInfoRow('Address', assignment.businessAddress!),
          
          // Inspection Date
          if (assignment.inspectionDate != null)
            _buildNeumorphicInfoRow('Inspection Date', assignment.inspectionDate!),
          
          // Assigned Date
          _buildNeumorphicInfoRow('Assigned Date', assignment.assignedAt),
          
          // Assigned By
          if (assignment.assignedByName != null)
            _buildNeumorphicInfoRow('Assigned By', assignment.assignedByName!),
          
          // Notes
          if (assignment.assignmentNotes != null && assignment.assignmentNotes!.isNotEmpty)
            _buildNeumorphicInfoRow('Notes', assignment.assignmentNotes!),
          
          const SizedBox(height: 20),
          
          // Action Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(8, 111, 222, 0.977),
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFFE2E8F0),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                _showAssignmentDetails(assignment);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
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

  Widget _buildNeumorphicInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
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

  // Original methods (keeping for compatibility)
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
                    color: Color(0xFF1F2937),
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
                color: Color(0xFF6B7280),
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
