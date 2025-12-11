import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/inspection.dart';
import '../widgets/media_capture_widget.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/hive_offline_database.dart';
import '../services/backup_service.dart';
import '../services/auth_service.dart';
import '../services/inspection_service.dart';
import '../services/connectivity_service.dart';
import '../models/user.dart';
import '../config/app_config.dart';
import 'inspection_form_screen.dart';
import 'email_report_screen.dart';
import 'sms_report_screen.dart';
import 'inspection_history_screen.dart';
import 'trash_screen.dart';
import '../services/trash_service.dart';

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
  
  // Lazy loading state
  int _displayedCount = 20; // Show first 20 items
  static const int _itemsPerPage = 20;

  // Helper function to check if a path is a network URL or server path
  bool _isNetworkPath(String path) {
    if (path.isEmpty) return false;
    // Check for full URLs
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return true;
    }
    // Check for server relative paths
    if (path.startsWith('uploads/') || path.startsWith('/uploads/')) {
      return true;
    }
    // Check for blob URLs
    if (path.startsWith('blob:')) {
      return true;
    }
    return false;
  }

  int? _extractServerInspectionId(Inspection inspection) {
    final rawId = inspection.id;
    if (rawId.isEmpty) return null;
    if (rawId.startsWith('inspection_')) {
      final parts = rawId.split('_');
      if (parts.length > 1) {
        return int.tryParse(parts.last);
      }
    }
    return int.tryParse(rawId);
  }

  Future<bool> _serverRecordExists(Inspection inspection) async {
    final serverId = _extractServerInspectionId(inspection);
    if (serverId == null) {
      return false;
    }

    try {
      final response = await InspectionService.getInspection(serverId);
      final success = response['success'] == true;
      final data = response['data'] ?? response['inspection'] ?? response['result'];
      if (!success || data == null) {
        return false;
      }
      return true;
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      if (errorText.contains('404') ||
          errorText.contains('not found') ||
          errorText.contains('no inspection')) {
        return false;
      }
      // For other errors (e.g., connectivity issues) assume record exists to avoid duplicates
      return true;
    }
  }

  // Helper function to normalize and get full URL for images
  Future<String> _getFullImageUrl(String path) async {
    if (path.isEmpty) return path;
    
    // If already a full URL, validate and return
    if (path.startsWith('http://') || path.startsWith('https://')) {
      try {
        // Validate URL format
        final uri = Uri.parse(path);
        // Reconstruct to ensure proper format (handles spaces and special chars)
        final reconstructed = uri.toString();
        print('Using full URL: $reconstructed');
        return reconstructed;
      } catch (e) {
        print('Error parsing URL, using original: $path - $e');
        return path;
      }
    }
    
    // If it's a relative server path, construct full URL
    if (path.startsWith('uploads/') || path.startsWith('/uploads/')) {
      try {
        final baseUrl = await AppConfig.baseUrl;
        // baseUrl is like "http://192.168.0.115/OBO-LGU/api"
        // Convert to web root: "http://192.168.0.115/OBO-LGU"
        final webBaseUrl = baseUrl.replaceAll('/api', '');
        final cleanPath = path.startsWith('/') ? path.substring(1) : path;
        // Build URI to handle encoding properly
        final fullUrl = Uri.parse('$webBaseUrl/$cleanPath').toString();
        print('Constructed URL from relative path: $fullUrl');
        return fullUrl;
      } catch (e) {
        print('Error getting base URL: $e');
        return path.startsWith('/') ? path : '/$path';
      }
    }
    
    // Return as-is for local paths
    return path;
  }

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
        // Reset lazy loading count
        _displayedCount = userInspections.length > _itemsPerPage ? _itemsPerPage : userInspections.length;
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

    // Reset displayed count when filters change
    if (_displayedCount > filtered.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _displayedCount = filtered.length > _itemsPerPage ? _itemsPerPage : filtered.length;
          });
        }
      });
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final orientation = MediaQuery.of(context).orientation;
    
    final isLargeTablet = screenWidth > 900;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 500;
    final isLandscape = orientation == Orientation.landscape;
    
    final double baseHeight = isLandscape ? 600.0 : 800.0;
    final double scale = (screenHeight / baseHeight).clamp(0.6, 1.3);
    final double smallScreenScale = isVerySmallScreen ? 0.8 : 1.0;
    final double finalScale = scale * smallScreenScale;
    
    return Container(
      padding: EdgeInsets.all((isLargeTablet ? 24.0 : (isTablet ? 20.0 : (isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0)))) * finalScale),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8FAFC),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Section
          Container(
            width: (isLargeTablet ? 56.0 : (isTablet ? 52.0 : (isVerySmallScreen ? 44.0 : (isSmallScreen ? 46.0 : 50.0)))) * finalScale,
            height: (isLargeTablet ? 56.0 : (isTablet ? 52.0 : (isVerySmallScreen ? 44.0 : (isSmallScreen ? 46.0 : 50.0)))) * finalScale,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromRGBO(8, 111, 222, 0.977),
                  Color.fromRGBO(22, 127, 239, 0.976),
                ],
              ),
              borderRadius: BorderRadius.circular((isLargeTablet ? 16.0 : (isTablet ? 14.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0)))) * finalScale),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(8, 111, 222, 0.25),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              Icons.assessment_rounded,
              color: Colors.white,
              size: (isLargeTablet ? 28.0 : (isTablet ? 26.0 : (isVerySmallScreen ? 22.0 : (isSmallScreen ? 23.0 : 25.0)))) * finalScale,
            ),
          ),
          SizedBox(width: (isLargeTablet ? 16.0 : (isTablet ? 14.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0)))) * finalScale),
          
          // Title and Subtitle Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Inspection Reports',
                  style: TextStyle(
                    fontSize: (isLargeTablet ? 26.0 : (isTablet ? 24.0 : (isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 22.0)))) * finalScale,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: (isVerySmallScreen ? 2.0 : (isSmallScreen ? 3.0 : 4.0)) * finalScale),
                Text(
                  _currentUser != null 
                      ? 'View your submitted inspections'
                      : 'View all submitted inspections',
                  style: TextStyle(
                    fontSize: (isLargeTablet ? 15.0 : (isTablet ? 14.0 : (isVerySmallScreen ? 11.0 : (isSmallScreen ? 12.0 : 13.0)))) * finalScale,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(width: (isLargeTablet ? 12.0 : (isTablet ? 10.0 : 8.0)) * finalScale),
          
          // Count Badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: (isLargeTablet ? 14.0 : (isTablet ? 12.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 9.0 : 10.0)))) * finalScale,
              vertical: (isLargeTablet ? 8.0 : (isTablet ? 7.0 : (isVerySmallScreen ? 5.0 : (isSmallScreen ? 5.5 : 6.0)))) * finalScale,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromRGBO(8, 111, 222, 0.977),
                  Color.fromRGBO(22, 127, 239, 0.976),
                ],
              ),
              borderRadius: BorderRadius.circular((isLargeTablet ? 12.0 : (isTablet ? 10.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 9.0 : 10.0)))) * finalScale),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(8, 111, 222, 0.3),
                  offset: Offset(0, 3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_rounded,
                  color: Colors.white,
                  size: (isLargeTablet ? 18.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0)))) * finalScale,
                ),
                SizedBox(width: (isVerySmallScreen ? 4.0 : (isSmallScreen ? 5.0 : 6.0)) * finalScale),
                Text(
                  '${_inspections.length}',
                  style: TextStyle(
                    fontSize: (isLargeTablet ? 18.0 : (isTablet ? 16.0 : (isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0)))) * finalScale,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(width: (isLargeTablet ? 10.0 : (isTablet ? 8.0 : 6.0)) * finalScale),
          
          // Action buttons row - Refresh and Trash
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Refresh button (icon only, square)
              Container(
                width: (isLargeTablet ? 48.0 : (isTablet ? 44.0 : (isVerySmallScreen ? 40.0 : (isSmallScreen ? 42.0 : 44.0)))) * finalScale,
                height: (isLargeTablet ? 48.0 : (isTablet ? 44.0 : (isVerySmallScreen ? 40.0 : (isSmallScreen ? 42.0 : 44.0)))) * finalScale,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular((isLargeTablet ? 12.0 : (isTablet ? 10.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 9.0 : 10.0)))) * finalScale),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular((isLargeTablet ? 12.0 : (isTablet ? 10.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 9.0 : 10.0)))) * finalScale),
                    onTap: _loadInspections,
                    child: Center(
                      child: Icon(
                        Icons.refresh_rounded,
                        color: const Color.fromRGBO(8, 111, 222, 0.977),
                        size: (isLargeTablet ? 24.0 : (isTablet ? 22.0 : (isVerySmallScreen ? 18.0 : (isSmallScreen ? 19.0 : 21.0)))) * finalScale,
                      ),
                    ),
                  ),
                ),
              ),
              
              SizedBox(width: (isLargeTablet ? 8.0 : (isTablet ? 6.0 : 4.0)) * finalScale),
              
              // Trash button (icon only, square)
              Container(
                width: (isLargeTablet ? 48.0 : (isTablet ? 44.0 : (isVerySmallScreen ? 40.0 : (isSmallScreen ? 42.0 : 44.0)))) * finalScale,
                height: (isLargeTablet ? 48.0 : (isTablet ? 44.0 : (isVerySmallScreen ? 40.0 : (isSmallScreen ? 42.0 : 44.0)))) * finalScale,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular((isLargeTablet ? 12.0 : (isTablet ? 10.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 9.0 : 10.0)))) * finalScale),
                  border: Border.all(
                    color: const Color(0xFFFECACA),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular((isLargeTablet ? 12.0 : (isTablet ? 10.0 : (isVerySmallScreen ? 8.0 : (isSmallScreen ? 9.0 : 10.0)))) * finalScale),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TrashScreen(),
                        ),
                      );
                    },
                    child: Center(
                      child: Icon(
                        Icons.delete_outline,
                        color: const Color(0xFFDC2626),
                        size: (isLargeTablet ? 24.0 : (isTablet ? 22.0 : (isVerySmallScreen ? 18.0 : (isSmallScreen ? 19.0 : 21.0)))) * finalScale,
                      ),
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

  Widget _buildSearchAndFilter(BuildContext context, bool isTablet) {
    final double padding = isTablet ? 22 : 18;
    final double radius = isTablet ? 16 : 14;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16, vertical: isTablet ? 18 : 14),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           
            const SizedBox(height: 15),
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  // Reset displayed count when search changes
                  _displayedCount = _itemsPerPage;
                });
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF3B82F6)),
                hintText: 'Search by business ID or inspection number...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 18 : 14,
                  vertical: isTablet ? 18 : 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Status',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildFilterChip('All', _selectedStatus == 'All', () {
                  setState(() {
                    _selectedStatus = 'All';
                    _displayedCount = _itemsPerPage;
                  });
                }, isTablet),
                _buildFilterChip('Pending', _selectedStatus == 'Pending', () {
                  setState(() {
                    _selectedStatus = 'Pending';
                    _displayedCount = _itemsPerPage;
                  });
                }, isTablet),
                _buildFilterChip('Completed', _selectedStatus == 'Completed', () {
                  setState(() {
                    _selectedStatus = 'Completed';
                    _displayedCount = _itemsPerPage;
                  });
                }, isTablet),
              ],
            ),
          ],
        ),
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
    // Lazy loading: Show items incrementally
    final displayedItems = _filteredInspections.take(_displayedCount).toList();
    final hasMore = _filteredInspections.length > _displayedCount;
    
    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      itemCount: displayedItems.length + (hasMore ? 1 : 0), // +1 for "Load More" button
      itemBuilder: (context, index) {
        if (index < displayedItems.length) {
          final inspection = displayedItems[index];
          return _buildInspectionCard(inspection, isTablet);
        } else {
          // "Load More" button
          return Container(
            margin: const EdgeInsets.only(top: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _displayedCount += _itemsPerPage;
                  if (_displayedCount > _filteredInspections.length) {
                    _displayedCount = _filteredInspections.length;
                  }
                });
              },
              icon: const Icon(Icons.expand_more),
              label: Text('Load More (${_filteredInspections.length - _displayedCount} remaining)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 14 : 12,
                  horizontal: isTablet ? 20 : 16,
                ),
              ),
            ),
          );
        }
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
                            'Business ID: ${inspection.scannedData}',
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F2937),
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
                            inspection.isSynced ? 'Exported' : 'Pending',
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InspectionHistoryScreen(
                                  inspectionId: inspection.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFEFF6FF),
                            foregroundColor: const Color(0xFF3B82F6),
                            side: const BorderSide(color: Color(0xFFDBEAFE), width: 1),
                            padding: EdgeInsets.all(isTablet ? 8 : 6),
                          ),
                          tooltip: 'View History',
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
                
                if (_hasPermitInformation(inspection)) ...[
                  SizedBox(height: isTablet ? 12 : 10),
                  _buildPermitStatsRow(inspection, isTablet),
                ],
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

  Widget _buildPermitStatsRow(Inspection inspection, bool isTablet) {
    Color _statusColor(bool? value, {bool caution = false}) {
      if (value == null) return const Color(0xFF94A3B8);
      if (value) {
        return caution ? const Color(0xFFF97316) : const Color(0xFF10B981);
      }
      return const Color(0xFFEF4444);
    }

    IconData _statusIcon(bool? value, {bool caution = false}) {
      if (value == null) return Icons.help_outline_rounded;
      if (value) {
        return caution ? Icons.warning_amber_rounded : Icons.check_circle_rounded;
      }
      return Icons.close_rounded;
    }

    final buildingColor = _statusColor(inspection.hasBuildingPermit);
    final occupancyColor = _statusColor(
      inspection.hasOccupancyPermit,
      caution: inspection.hasOccupancyPermit == true &&
          (inspection.occupancyPermitRecommendation != null &&
              inspection.occupancyPermitRecommendation != 'Approved'),
    );

    final buildingIcon = _statusIcon(inspection.hasBuildingPermit);
    final occupancyIcon = _statusIcon(
      inspection.hasOccupancyPermit,
      caution: inspection.hasOccupancyPermit == true &&
          (inspection.occupancyPermitRecommendation != null &&
              inspection.occupancyPermitRecommendation != 'Approved'),
    );

    String _statusLabel(bool? value) {
      if (value == null) return 'N/A';
      return value ? 'Yes' : 'No';
    }

    String _recommendationText(String? recommendation) {
      if (recommendation == null || recommendation.trim().isEmpty) {
        return 'No recommendation provided.';
      }
      return recommendation;
    }

    String _occupancyAgeText() {
      if (inspection.hasOccupancyPermit == true && inspection.occupancyPermitIssuedYear != null) {
        final currentYear = DateTime.now().year;
        final year = inspection.occupancyPermitIssuedYear!;
        if (year >= 1900 && year <= currentYear) {
          final age = currentYear - year;
          return 'Issued $year (${age} year${age == 1 ? '' : 's'} old)';
        }
        return 'Issued year: $year';
      }
      return 'Issued year: N/A';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 12 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in_rounded, color: const Color(0xFF0284C7), size: isTablet ? 18 : 16),
              const SizedBox(width: 6),
              Text(
                'Permit Overview',
                style: TextStyle(
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: buildingColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: buildingColor.withOpacity(0.4), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(buildingIcon, color: buildingColor, size: isTablet ? 16 : 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Building Permit',
                              style: TextStyle(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                                color: buildingColor,
                              ),
                            ),
                          ),
                          Text(
                            _statusLabel(inspection.hasBuildingPermit),
                            style: TextStyle(
                              fontSize: isTablet ? 11 : 9,
                              fontWeight: FontWeight.w600,
                              color: buildingColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _recommendationText(inspection.buildingPermitRecommendation),
                        style: TextStyle(
                          fontSize: isTablet ? 10 : 9,
                          color: buildingColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: occupancyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: occupancyColor.withOpacity(0.4), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(occupancyIcon, color: occupancyColor, size: isTablet ? 16 : 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Occupancy Permit',
                              style: TextStyle(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                                color: occupancyColor,
                              ),
                            ),
                          ),
                          Text(
                            _statusLabel(inspection.hasOccupancyPermit),
                            style: TextStyle(
                              fontSize: isTablet ? 11 : 9,
                              fontWeight: FontWeight.w600,
                              color: occupancyColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _occupancyAgeText(),
                        style: TextStyle(
                          fontSize: isTablet ? 10 : 8.5,
                          color: occupancyColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _recommendationText(inspection.occupancyPermitRecommendation),
                        style: TextStyle(
                          fontSize: isTablet ? 10 : 9,
                          color: occupancyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInspectionDetails(Inspection inspection, bool isTablet) {
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
                      _buildExportButton(inspection, isTablet),
                      const SizedBox(height: 20),
                      
                      // Business ID (from scanned QR code)
                      _buildSectionCard('Business ID', inspection.scannedData, Icons.qr_code_rounded, isTablet),
                      const SizedBox(height: 16),

                      // Permit Summary
                      if (_hasPermitInformation(inspection)) ...[
                        _buildPermitSummaryCard(inspection, isTablet),
                        const SizedBox(height: 16),
                      ],
                      
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

  bool _hasPermitInformation(Inspection inspection) {
    return inspection.hasBuildingPermit != null ||
        inspection.hasOccupancyPermit != null ||
        inspection.occupancyPermitIssuedYear != null ||
        (inspection.buildingPermitRecommendation?.isNotEmpty ?? false) ||
        (inspection.occupancyPermitRecommendation?.isNotEmpty ?? false) ||
        (inspection.buildingPermitId?.isNotEmpty ?? false) ||
        (inspection.occupancyPermitId?.isNotEmpty ?? false);
  }

  Widget _buildPermitSummaryCard(Inspection inspection, bool isTablet) {
    final bool? hasBuildingPermit = inspection.hasBuildingPermit;
    final bool? hasOccupancyPermit = inspection.hasOccupancyPermit;
    final int? occupancyYear = inspection.occupancyPermitIssuedYear;
    final String? buildingRecommendation = inspection.buildingPermitRecommendation;
    final String? occupancyRecommendation = inspection.occupancyPermitRecommendation;
    final String? buildingPermitId = inspection.buildingPermitId;
    final String? occupancyPermitId = inspection.occupancyPermitId;

    Color _statusColor(bool? value, {bool isOccupancy = false, String? recommendation}) {
      if (value == null) return const Color(0xFF6B7280); // N/A - gray
      if (value) {
        // Check for expired status first (case insensitive)
        if (recommendation != null && recommendation.toLowerCase().contains('expired')) {
          return const Color(0xFFEF4444); // Expired - red
        }
        // Check for approved status (case insensitive)
        if (recommendation != null && recommendation.toUpperCase().contains('APPROVED')) {
          return const Color(0xFF10B981); // Approved - green
        }
        // Default for YES but no recommendation yet - green
        return const Color(0xFF10B981);
      }
      return const Color(0xFFEF4444); // No - red
    }

    IconData _statusIcon(bool? value, {bool isOccupancy = false, String? recommendation}) {
      if (value == null) return Icons.remove_circle_outline_rounded; // N/A
      if (value) {
        // Check for expired status first (case insensitive)
        if (recommendation != null && recommendation.toLowerCase().contains('expired')) {
          return Icons.error_rounded; // Expired - error icon
        }
        // Check for approved status (case insensitive)
        if (recommendation != null && recommendation.toUpperCase().contains('APPROVED')) {
          return Icons.check_circle_rounded; // Approved - green check
        }
        // Default for YES but no recommendation yet - green check
        return Icons.check_circle_rounded;
      }
      return Icons.close_rounded; // No
    }

    final currentYear = DateTime.now().year;
    int? occupancyAge;
    if (occupancyYear != null && occupancyYear >= 1900 && occupancyYear <= currentYear) {
      occupancyAge = currentYear - occupancyYear;
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Permit Requirements',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPermitDetailSection(
            title: 'Building Permit',
            statusLabel: hasBuildingPermit == null
                ? 'N/A'
                : (hasBuildingPermit ? 'Yes' : 'No'),
            icon: _statusIcon(hasBuildingPermit),
            color: _statusColor(hasBuildingPermit),
            isTablet: isTablet,
            details: [
              if (hasBuildingPermit == true && buildingPermitId != null && buildingPermitId.isNotEmpty) ...[
                Text(
                  'Building Permit ID: $buildingPermitId',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: const Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
            recommendation: buildingRecommendation,
          ),
          const SizedBox(height: 12),
          _buildPermitDetailSection(
            title: 'Occupancy Permit',
            statusLabel: hasOccupancyPermit == null
                ? 'N/A'
                : (hasOccupancyPermit ? 'Yes' : 'No'),
            icon: _statusIcon(
              hasOccupancyPermit,
              isOccupancy: true,
              recommendation: occupancyRecommendation,
            ),
            color: _statusColor(
              hasOccupancyPermit,
              isOccupancy: true,
              recommendation: occupancyRecommendation,
            ),
            isTablet: isTablet,
            details: [
              if (hasOccupancyPermit == true && occupancyPermitId != null && occupancyPermitId.isNotEmpty) ...[
                Text(
                  'Occupancy Permit ID: $occupancyPermitId',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: const Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (hasOccupancyPermit == true && occupancyYear != null) ...[
                if (occupancyPermitId != null && occupancyPermitId.isNotEmpty) const SizedBox(height: 4),
                Text(
                  'Issued Year: $occupancyYear'
                  '${occupancyAge != null ? ' (${occupancyAge} year${occupancyAge == 1 ? '' : 's'} old)' : ''}',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: const Color(0xFF374151),
                  ),
                ),
              ],
            ],
            recommendation: occupancyRecommendation,
          ),
        ],
      ),
    );
  }

  Widget _buildPermitDetailSection({
    required String title,
    required String statusLabel,
    required IconData icon,
    required Color color,
    required bool isTablet,
    List<Widget>? details,
    String? recommendation,
  }) {
    final detailWidgets = details ?? [];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 12 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 10 : 8,
                  vertical: isTablet ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: color,
                      size: isTablet ? 14 : 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detailWidgets.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...detailWidgets,
          ],
          if (recommendation != null && recommendation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 10 : 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: color,
                    size: isTablet ? 16 : 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
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
        isSynced: false,
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

  Widget _buildExportButton(Inspection inspection, bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: () => _showTransactionOptions(context, inspection, isTablet),
          icon: const Icon(Icons.playlist_add_check_rounded, color: Colors.white),
          label: Text(
            'Transactions',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 18 : 16,
              horizontal: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  void _showTransactionOptions(
    BuildContext context,
    Inspection inspection,
    bool isTablet,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 16,
            vertical: isTablet ? 20 : 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Color(0xFF10B981)),
                title: const Text('Export Report'),
                subtitle: const Text('Generate a report for server or offline use'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showExportOptions(inspection, isTablet);
                },
              ),
              ListTile(
                leading: const Icon(Icons.email_rounded, color: Color(0xFF3B82F6)),
                title: const Text('Send Email'),
                subtitle: const Text('Compose an email report'),
                onTap: () {
                  Navigator.of(context).pop();
                  _sendEmailReport(inspection, isTablet);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sms_rounded, color: Color(0xFFF97316)),
                title: const Text('Send SMS'),
                subtitle: const Text('Open SMS screen with summary'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openSmsScreen(inspection);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_rounded, color: Color(0xFF0EA5E9)),
                title: const Text('Create Excel Backup'),
                subtitle: const Text('Export all inspections to an Excel file'),
                onTap: () {
                  Navigator.of(context).pop();
                  _generateExcelBackup(isTablet);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateExcelBackup(bool isTablet) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: isTablet ? 20 : 16),
              Text(
                'Generating Excel backup...',
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      );

      final result = await BackupService.exportInspectionsToExcel();

      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      final snackBar = SnackBar(
        content: Text(result.message),
        backgroundColor: result.success
            ? const Color(0xFF10B981)
            : const Color(0xFFDC2626),
        duration: const Duration(seconds: 4),
        action: (result.success && result.filePath != null && !kIsWeb)
            ? SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () {
                  final path = result.filePath;
                  if (path != null) {
                    Share.shareXFiles([XFile(path)]);
                  }
                },
              )
            : null,
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create backup: $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showExportOptions(Inspection inspection, bool isTablet) {
    final connectivityService = ConnectivityService();
    final isConnected = connectivityService.isConnected;

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
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.download_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Export Options',
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
              'Choose how you want to export this inspection:',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 16),
            
            // Export Directly Option
            _buildExportOption(
              'Export Directly',
              isConnected 
                  ? 'Sync inspection to server when connected'
                  : 'Requires internet connection',
              Icons.cloud_upload_rounded,
              isConnected ? const Color(0xFF10B981) : const Color(0xFF6B7280),
              isConnected,
              () => _exportDirectly(inspection, isTablet),
              isTablet,
            ),
            const SizedBox(height: 12),
            
            // Scan QR Code Option (Coming Soon)
            _buildExportOption(
              'Scan QR Code',
              'Coming soon: Share via QR code',
              Icons.qr_code_scanner_rounded,
              const Color(0xFFF59E0B),
              false,
              () => _showQRCodeComingSoon(isTablet),
              isTablet,
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
        ],
      ),
    );
  }

  Widget _buildExportOption(
    String title,
    String description,
    IconData icon,
    Color color,
    bool isEnabled,
    VoidCallback onTap,
    bool isTablet,
  ) {
    return InkWell(
      onTap: isEnabled ? () {
        Navigator.of(context).pop(); // Close dialog first
        onTap();
      } : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          padding: EdgeInsets.all(isTablet ? 12 : 10),
          decoration: BoxDecoration(
            color: isEnabled ? color.withOpacity(0.1) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEnabled ? color : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEnabled ? color.withOpacity(0.2) : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isTablet ? 18 : 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (!isEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SOON',
                              style: TextStyle(
                                fontSize: isTablet ? 8 : 7,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isEnabled ? color : const Color(0xFF6B7280),
                size: isTablet ? 16 : 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportDirectly(Inspection inspection, bool isTablet) async {
    // Prevent exporting when there are no changes to sync, unless the server copy is missing
    if (inspection.isSynced) {
      final exists = await _serverRecordExists(inspection);
      if (exists) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('Already Exported'),
                ],
              ),
              content: const Text(
                'This inspection is already exported and there are no unsynced changes. '
                'Make updates first before exporting again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      } else {
        // Server record is missing; mark as unsynced so we can create it again
        inspection.isSynced = false;
        inspection.updatedAt = DateTime.now();
        await HiveOfflineDatabase.saveInspection(inspection);
      }
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              'Exporting inspection to server...',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Check connectivity
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Text('No Internet Connection'),
                ],
              ),
              content: const Text(
                'Please connect to the internet to export the inspection to the server.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Determine if inspection should be created or updated
      // Always try to create first if not synced, or update if synced and has server ID
      int? serverInspectionId;
      if (inspection.id.startsWith('inspection_')) {
        final idParts = inspection.id.split('_');
        if (idParts.length > 1) {
          // Try to parse the numeric part as server ID
          // If it's a timestamp (very long number), it's a local ID
          final numericPart = idParts.last;
          final parsedId = int.tryParse(numericPart);
          // If parsed ID is reasonable (less than 10 digits), treat as server ID
          // Timestamps are usually 13 digits, server IDs are usually smaller
          if (parsedId != null && numericPart.length < 10) {
            serverInspectionId = parsedId;
          }
        }
      } else {
        serverInspectionId = int.tryParse(inspection.id);
      }

      print('Export inspection - ID: ${inspection.id}, IsSynced: ${inspection.isSynced}, ServerID: $serverInspectionId');

      final bool hasServerId = serverInspectionId != null;
      bool performedUpdate = false;
      Map<String, dynamic>? result;
      if (hasServerId) {
        try {
          // Update existing inspection
          print('Updating existing inspection with server ID: $serverInspectionId');
          result = await InspectionService.updateInspection(inspection);
          performedUpdate = true;
          print('Update result: $result');
        } catch (e) {
          final errorText = e.toString().toLowerCase();
          final bool isMissingOnServer = errorText.contains('404') ||
              errorText.contains('not found') ||
              errorText.contains('access denied');
          if (isMissingOnServer) {
            print('Server update failed because inspection was not found. Falling back to create.');
            inspection.isSynced = false;
            inspection.updatedAt = DateTime.now();
            final oldId = inspection.id;
            final hadServerId = _extractServerInspectionId(inspection) != null;
            if (hadServerId) {
              inspection.id = 'inspection_${DateTime.now().millisecondsSinceEpoch}';
              await HiveOfflineDatabase.deleteInspection(oldId);
            }
            await HiveOfflineDatabase.saveInspection(inspection);
            serverInspectionId = null;
          } else {
            rethrow;
          }
        }
      }

      if (!performedUpdate) {
        // Create new inspection
        print('Creating new inspection');
        result = await InspectionService.createInspection(inspection);
        print('Create result: $result');
        
        // Update local inspection with server ID if returned
        if (result != null && result['success'] == true && result['server_inspection_id'] != null) {
          final oldId = inspection.id;
          final serverId = result['server_inspection_id'];
          print('Updating local inspection: oldId=$oldId, newServerId=$serverId');
          inspection.id = 'inspection_$serverId';
          await HiveOfflineDatabase.deleteInspection(oldId);
          await HiveOfflineDatabase.saveInspection(inspection);
        }
      }

      result ??= {'success': false, 'message': 'Unknown export result'};

      // Verify result
      if (result['success'] != true) {
        final errorMsg = result['message'] ?? result['data']?['message'] ?? 'Unknown error occurred';
        throw Exception(errorMsg);
      }

      // Mark as synced and persist
      inspection.isSynced = true;
      inspection.updatedAt = DateTime.now();
      await HiveOfflineDatabase.saveInspection(inspection);
      await HiveOfflineDatabase.markInspectionAsSynced(inspection.id);

      // Refresh database cache on server side to ensure data is immediately visible
      // Add a small delay to ensure transaction is fully committed
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('Refreshing database cache to make exported data visible...');
      try {
        final refreshSuccess = await InspectionService.refreshDatabase();
        if (refreshSuccess) {
          print('Database cache refreshed successfully - data should now be visible');
        } else {
          print('Database cache refresh failed (non-critical)');
        }
      } catch (e) {
        // Non-critical error - don't block export success
        print('Error refreshing database cache (non-critical): $e');
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success dialog
      if (mounted) {
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
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Export Successful',
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
                  'Your inspection has been successfully exported to the server and the database has been refreshed.',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
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
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF10B981), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Inspection Details:',
                            style: TextStyle(
                              fontSize: isTablet ? 12 : 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ID: ${inspection.id.substring(inspection.id.length - 8)}',
                        style: TextStyle(
                          fontSize: isTablet ? 11 : 9,
                          color: const Color(0xFF10B981),
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        'Status: ${performedUpdate ? 'Updated' : 'Created'}',
                        style: TextStyle(
                          fontSize: isTablet ? 11 : 9,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        'Synced: Yes',
                        style: TextStyle(
                          fontSize: isTablet ? 11 : 9,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Refresh the inspection list
                  _loadInspections();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 12 : 10,
                  ),
                ),
                child: Text(
                  'OK',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error dialog
      if (mounted) {
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
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Export Failed',
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
                  'Failed to export inspection to server.',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA), width: 1),
                  ),
                  child: Text(
                    'Error: ${e.toString().replaceAll('Exception: ', '')}',
                    style: TextStyle(
                      fontSize: isTablet ? 11 : 9,
                      color: const Color(0xFFDC2626),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
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
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF0EA5E9), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The inspection is still saved locally and will sync automatically when online.',
                          style: TextStyle(
                            fontSize: isTablet ? 11 : 9,
                            color: const Color(0xFF0EA5E9),
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
                  'OK',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showQRCodeComingSoon(bool isTablet) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'QR Code export feature coming soon!',
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
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
              children: images.map((imagePath) {
                print('Building section image widget for path: $imagePath');
                return GestureDetector(
                  onTap: () => _previewImage(imagePath),
                  child: Container(
                    width: isTablet ? 60 : 50,
                    height: isTablet ? 60 : 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: _buildImageWidget(imagePath, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                );
              }).toList(),
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
          // Overall media (legacy)
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

          const SizedBox(height: 12),
          // Per-section media
          if ((inspection.sectionImagePaths != null && inspection.sectionImagePaths!.isNotEmpty) ||
              (inspection.sectionVideoPaths != null && inspection.sectionVideoPaths!.isNotEmpty)) ...[
            Row(
              children: [
                Icon(Icons.collections_rounded, color: const Color(0xFF3B82F6), size: isTablet ? 18 : 16),
                const SizedBox(width: 6),
                Text(
                  'Section Media',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildSectionMediaCards(inspection, isTablet),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSectionMediaCards(Inspection inspection, bool isTablet) {
    final List<Widget> widgets = [];
    final imagesMap = inspection.sectionImagePaths ?? {};
    final videosMap = inspection.sectionVideoPaths ?? {};

    Set<String> sections = {
      ...imagesMap.keys,
      ...videosMap.keys,
    };

    for (final section in sections) {
      final images = List<String>.from(imagesMap[section] ?? const []);
      final videos = List<String>.from(videosMap[section] ?? const []);
      if (images.isEmpty && videos.isEmpty) continue;

      widgets.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section,
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            if (images.isNotEmpty) ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isTablet ? 4 : 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final path = images[index];
                  print('Building section media image widget for path: $path');
                  return GestureDetector(
                    onTap: () => _previewImage(path),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: _buildImageWidget(path, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
            ],
            if (videos.isNotEmpty) ...[
              ...videos.asMap().entries.map((e) {
                final idx = e.key;
                final vpath = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white),
                    ),
                    title: Text(
                      'Video ${idx + 1}',
                      style: TextStyle(fontSize: isTablet ? 12 : 10),
                    ),
                    subtitle: Text(
                      'Tap to play',
                      style: TextStyle(fontSize: isTablet ? 10 : 9, color: const Color(0xFF6B7280)),
                    ),
                    onTap: () => _previewVideo(vpath),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ));
    }
    return widgets;
  }

  void _previewImage(String path) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: _buildImageWidget(path, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  // Dynamic image widget that handles both web and mobile
  Widget _buildImageWidget(String path, {BoxFit fit = BoxFit.cover}) {
    if (path.isEmpty) {
      return _buildErrorWidget('Empty path');
    }

    // On mobile, always try to find local file first (even for network paths)
    // This ensures offline viewing works with files stored in Hive
    if (!kIsWeb) {
      // Check if it looks like a local file path first
      if (!_isNetworkPath(path)) {
        // Definitely a local path
        return _buildLocalImage(path, fit: fit);
      } else {
        // Network path - but check for local file first on mobile
        return _buildNetworkImage(path, fit: fit);
      }
    } else {
      // On web, use network for network paths, error for local paths
      if (_isNetworkPath(path)) {
        return _buildNetworkImage(path, fit: fit);
      } else {
        return _buildErrorWidget('Local file not accessible on web');
      }
    }
  }

  // Build network image (for both web and mobile)
  // On mobile, first checks for local file before loading from network
  Widget _buildNetworkImage(String path, {BoxFit fit = BoxFit.cover}) {
    // On mobile, try to find local file first
    if (!kIsWeb) {
      return FutureBuilder<String?>(
        future: _findLocalFile(path),
        builder: (context, localSnapshot) {
          // If local file found, use it
          if (localSnapshot.hasData && localSnapshot.data != null) {
            return _buildLocalImage(localSnapshot.data!, fit: fit);
          }
          
          // If still checking for local file, show loading
          if (localSnapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingWidget();
          }
          
          // No local file found, load from network
          return _loadNetworkImage(path, fit: fit);
        },
      );
    }
    
    // On web, load directly from network
    return _loadNetworkImage(path, fit: fit);
  }

  // Load image from network
  Widget _loadNetworkImage(String path, {BoxFit fit = BoxFit.cover}) {
    return FutureBuilder<String>(
      future: _getFullImageUrl(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }
        
        if (snapshot.hasError) {
          print('Error getting full URL: ${snapshot.error}');
          return _buildErrorWidget('URL error: ${snapshot.error}');
        }
        
        final imageUrl = snapshot.data ?? path;
        print('Loading network image from URL: $imageUrl');
        
        return Image.network(
          imageUrl,
          fit: fit,
          headers: {
            // Add headers if needed for authentication
            'Accept': 'image/*',
          },
          errorBuilder: (context, error, stackTrace) {
            print('ERROR: Failed to load network image');
            print('URL: $imageUrl');
            print('Error: $error');
            return _buildErrorWidget('Failed to load image');
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('Image loaded successfully');
              return child;
            }
            return _buildLoadingWidget(
              progress: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            );
          },
          // Add cache settings for better performance
          cacheWidth: fit == BoxFit.cover ? 300 : null,
          cacheHeight: fit == BoxFit.cover ? 300 : null,
        );
      },
    );
  }

  // Build local image (mobile only)
  Widget _buildLocalImage(String path, {BoxFit fit = BoxFit.cover}) {
    if (kIsWeb) {
      // On web, local files are not accessible
      return _buildErrorWidget('Local file not accessible on web');
    }
    
    final file = File(path);
    
    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }
        
        if (snapshot.data == true) {
          print('Loading local image: $path');
          return Image.file(
            file,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              print('ERROR: Failed to load local image: $path');
              print('ERROR details: $error');
              // Try to load as network image if local fails and path is network path
              if (_isNetworkPath(path)) {
                print('Retrying as network image...');
                return _loadNetworkImage(path, fit: fit);
              }
              return _buildErrorWidget('Failed to load');
            },
            cacheWidth: fit == BoxFit.cover ? 300 : null,
            cacheHeight: fit == BoxFit.cover ? 300 : null,
          );
        } else {
          print('Local image file not found: $path');
          // If local file doesn't exist, try network if it's a network path
          if (_isNetworkPath(path)) {
            print('File not found locally, trying network...');
            return _loadNetworkImage(path, fit: fit);
          }
          return _buildErrorWidget('File not found');
        }
      },
    );
  }

  // Check if a local file exists for a given path (extract filename and search)
  Future<String?> _findLocalFile(String serverPath) async {
    if (kIsWeb) return null;
    
    try {
      // Extract filename from server path (handle both full URLs and relative paths)
      String fileName = serverPath.split('/').last;
      // Remove query parameters if any
      if (fileName.contains('?')) {
        fileName = fileName.split('?').first;
      }
      if (fileName.isEmpty) return null;
      
      print('Searching for local file with filename: $fileName');
      
      // Search in inspections directory
      final Directory baseDir = await getApplicationDocumentsDirectory();
      final Directory photosDir = Directory('${baseDir.path}/inspections/photos');
      final Directory videosDir = Directory('${baseDir.path}/inspections/videos');
      
      // Helper function to check if filename matches
      bool matchesFilename(String filePath, String targetName) {
        String normalizeName(String input) {
          if (input.isEmpty) return input;
          String base = input.toLowerCase();
          if (base.contains('.')) {
            base = base.split('.').first;
          }
          final parts = base.split('_').where((part) => part.isNotEmpty).toList();
          if (parts.isEmpty) return base;
          final List<String> filtered = [];
          bool trimmed = false;
          for (final part in parts) {
            final isNumeric = RegExp(r'^\d{6,}$').hasMatch(part);
            final isHex = RegExp(r'^[0-9a-f]{6,}$').hasMatch(part);
            if (!trimmed && (isNumeric || isHex)) {
              continue;
            }
            trimmed = true;
            filtered.add(part);
          }
          if (filtered.isEmpty) {
            filtered.addAll(parts.length > 2 ? parts.sublist(parts.length - 2) : parts);
          }
          return filtered.join('_');
        }

        final file = File(filePath);
        final name = file.path.split(Platform.pathSeparator).last;
        final nameWithoutExt = name.split('.').first.toLowerCase();
        final targetWithoutExt = targetName.split('.').first.toLowerCase();
        final normalizedName = normalizeName(name);
        final normalizedTarget = normalizeName(targetName);

        if (name == targetName || nameWithoutExt == targetWithoutExt) {
          return true;
        }
        if (name.contains(targetName) || nameWithoutExt.contains(targetWithoutExt)) {
          return true;
        }
        if (targetName.contains(name) || targetWithoutExt.contains(nameWithoutExt)) {
          return true;
        }
        if (normalizedName.isNotEmpty && normalizedTarget.isNotEmpty) {
          if (normalizedName == normalizedTarget) return true;
          if (normalizedName.contains(normalizedTarget) || normalizedTarget.contains(normalizedName)) return true;
          final nameSuffix = normalizedName.length > 20 ? normalizedName.substring(normalizedName.length - 20) : normalizedName;
          final targetSuffix = normalizedTarget.length > 20 ? normalizedTarget.substring(normalizedTarget.length - 20) : normalizedTarget;
          if (nameSuffix == targetSuffix) return true;
        }

        final nameTimestamp = name.split('_').first;
        final targetTimestamp = targetName.split('_').first;
        if (nameTimestamp.isNotEmpty && targetTimestamp.isNotEmpty) {
          try {
            final nameTime = int.tryParse(nameTimestamp);
            final targetTime = int.tryParse(targetTimestamp);
            if (nameTime != null && targetTime != null) {
              if ((nameTime - targetTime).abs() < 3600000) {
                return true;
              }
            }
          } catch (e) {}
        }

        return false;
      }
      
      // Check photos directory
      if (await photosDir.exists()) {
        final files = await photosDir.list().toList();
        for (var file in files) {
          if (file is File) {
            if (matchesFilename(file.path, fileName)) {
              print('Found local photo file: ${file.path} for server path: $serverPath');
              return file.path;
            }
          }
        }
      }
      
      // Check videos directory
      if (await videosDir.exists()) {
        final files = await videosDir.list().toList();
        for (var file in files) {
          if (file is File) {
            if (matchesFilename(file.path, fileName)) {
              print('Found local video file: ${file.path} for server path: $serverPath');
              return file.path;
            }
          }
        }
      }
      
      // Also check media_backup directory (fallback location)
      final Directory backupPhotosDir = Directory('${baseDir.path}/media_backup/photos');
      final Directory backupVideosDir = Directory('${baseDir.path}/media_backup/videos');
      
      if (await backupPhotosDir.exists()) {
        final files = await backupPhotosDir.list().toList();
        for (var file in files) {
          if (file is File && matchesFilename(file.path, fileName)) {
            print('Found local photo in backup: ${file.path}');
            return file.path;
          }
        }
      }
      
      if (await backupVideosDir.exists()) {
        final files = await backupVideosDir.list().toList();
        for (var file in files) {
          if (file is File && matchesFilename(file.path, fileName)) {
            print('Found local video in backup: ${file.path}');
            return file.path;
          }
        }
      }
      
      print('No local file found for: $fileName');
      return null;
    } catch (e) {
      print('Error searching for local file: $e');
      return null;
    }
  }

  // Helper widgets
  Widget _buildLoadingWidget({double? progress}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: progress != null
            ? CircularProgressIndicator(value: progress)
            : const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  void _previewVideo(String path) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: VideoPlayerWidget(videoPath: path),
          ),
        ),
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
          if (_hasPermitInformation(inspection)) ...[
            const SizedBox(height: 6),
            _buildDetailRow(
              'Building Permit',
              _formatPermitDetail(
                inspection.hasBuildingPermit,
                inspection.buildingPermitRecommendation,
              ),
              Icons.domain_rounded,
              isTablet,
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              'Occupancy Permit',
              _formatPermitDetail(
                inspection.hasOccupancyPermit,
                inspection.occupancyPermitRecommendation,
                issuedYear: inspection.occupancyPermitIssuedYear,
              ),
              Icons.apartment_rounded,
              isTablet,
            ),
          ],
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

  String _formatPermitDetail(bool? hasPermit, String? recommendation, {int? issuedYear}) {
    String status;
    if (hasPermit == null) {
      status = 'Status: Not provided';
    } else {
      status = 'Status: ${hasPermit ? 'Yes' : 'No'}';
    }

    String issuedText = '';
    if (issuedYear != null && hasPermit == true) {
      final currentYear = DateTime.now().year;
      if (issuedYear >= 1900 && issuedYear <= currentYear) {
        final age = currentYear - issuedYear;
        issuedText = ' | Issued: $issuedYear (${age} year${age == 1 ? '' : 's'} old)';
      } else {
        issuedText = ' | Issued: $issuedYear';
      }
    }

    final recommendationText = (recommendation != null && recommendation.trim().isNotEmpty)
        ? ' | Recommendation: $recommendation'
        : '';

    return '$status$issuedText$recommendationText';
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
                    'Move to Trash',
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
              'Move this inspection to trash?',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF0EA5E9), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can restore it later from the Trash screen.',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11,
                        color: const Color(0xFF0C4A6E),
                      ),
                    ),
                  ),
                ],
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
            child: const Text(
              'Move to Trash',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendEmailReport(Inspection inspection, bool isTablet) {
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
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.email_rounded,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Email & Share Options',
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
              'Choose how you want to share the inspection report:',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 16),
            
            // Email Options
            _buildEmailOption(
              'Send Email Report',
              'Send inspection report via email',
              Icons.email_outlined,
              () => _openEmailScreen(inspection, true, isTablet),
              isTablet,
            ),
            const SizedBox(height: 12),
            _buildEmailOption(
              'Share Report',
              'Share the report using your device\'s sharing options',
              Icons.share_rounded,
              () => _shareReport(inspection, isTablet),
              isTablet,
            ),
            const SizedBox(height: 12),
            _buildEmailOption(
              'Copy Report Data',
              'Copy inspection data to clipboard for manual sharing',
              Icons.copy_rounded,
              () => _copyReportData(inspection, isTablet),
              isTablet,
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
        ],
      ),
    );
  }

  Widget _buildEmailOption(String title, String description, IconData icon, VoidCallback onTap, bool isTablet) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop(); // Close dialog first
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 12 : 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF3B82F6),
                size: isTablet ? 18 : 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: const Color(0xFF6B7280),
              size: isTablet ? 16 : 14,
            ),
          ],
        ),
      ),
    );
  }

  void _openSmsScreen(Inspection inspection) {
    final inspectorName = _currentUser?.name ?? 'Unknown Inspector';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmsReportScreen(
          inspection: inspection,
          inspectorName: inspectorName,
        ),
      ),
    );
  }

  void _openEmailScreen(Inspection inspection, bool isDetailed, bool isTablet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailReportScreen(
          inspection: inspection,
          isDetailed: isDetailed,
        ),
      ),
    );
  }


  void _shareReport(Inspection inspection, bool isTablet) async {
    try {
      // Show loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing to share...'),
          backgroundColor: Color(0xFF3B82F6),
          duration: Duration(seconds: 1),
        ),
      );

      // Generate quick report content
      final reportContent = _generateQuickEmailTemplate(inspection);
      
      // Share the report
      await Share.share(
        reportContent,
        subject: 'Inspection Report #${inspection.id.substring(inspection.id.length - 8)}',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report shared!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing report: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyReportData(Inspection inspection, bool isTablet) async {
    try {
      // Show loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copying report...'),
          backgroundColor: Color(0xFF3B82F6),
          duration: Duration(milliseconds: 500),
        ),
      );

      // Generate quick report
      final reportData = _generateQuickEmailTemplate(inspection);
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: reportData));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report copied!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error copying report: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _generateQuickEmailTemplate(Inspection inspection) {
    final inspectorName = _currentUser?.name ?? 'Unknown Inspector';
    final createdDate = _formatDateTime(inspection.createdAt);
    
    // Quick status check
    final sectionStatuses = inspection.sectionStatus.values.toList();
    final hasInProgress = sectionStatuses.contains('in_progress');
    final hasPassed = sectionStatuses.contains('passed');
    final hasNotPassed = sectionStatuses.contains('not_passed');
    
    String status = 'No sections';
    if (sectionStatuses.isNotEmpty) {
      if (hasInProgress) status = 'In Progress';
      else if (hasPassed || hasNotPassed) status = 'Completed';
    }
    
    // Count completed sections
    int completedSections = 0;
    if (inspection.mechanicalRemarks.isNotEmpty || inspection.mechanicalAssessment.isNotEmpty) completedSections++;
    if (inspection.lineGradeRemarks.isNotEmpty || inspection.lineGradeAssessment.isNotEmpty) completedSections++;
    if (inspection.architecturalRemarks.isNotEmpty || inspection.architecturalAssessment.isNotEmpty) completedSections++;
    if (inspection.civilStructuralRemarks.isNotEmpty || inspection.civilStructuralAssessment.isNotEmpty) completedSections++;
    if (inspection.sanitaryPlumbingRemarks.isNotEmpty || inspection.sanitaryPlumbingAssessment.isNotEmpty) completedSections++;
    if (inspection.electricalElectronicsRemarks.isNotEmpty || inspection.electricalElectronicsAssessment.isNotEmpty) completedSections++;
    
    String _permitStatusText(bool? value) {
      if (value == null) return 'Not provided';
      return value ? 'Yes' : 'No';
    }

    String _permitRecommendation(String? recommendation) {
      if (recommendation == null || recommendation.trim().isEmpty) return 'None';
      return recommendation;
    }

    String occupancyAge = 'Issued year not available';
    if (inspection.hasOccupancyPermit == true && inspection.occupancyPermitIssuedYear != null) {
      final currentYear = DateTime.now().year;
      final issuedYear = inspection.occupancyPermitIssuedYear!;
      if (issuedYear >= 1900 && issuedYear <= currentYear) {
        final age = currentYear - issuedYear;
        occupancyAge = 'Issued $issuedYear (${age} year${age == 1 ? '' : 's'} old)';
      } else {
        occupancyAge = 'Issued $issuedYear';
      }
    }

    return '''INSPECTION REPORT SUMMARY

Inspection ID: ${inspection.id.substring(inspection.id.length - 8)}
Inspector: $inspectorName
Date: $createdDate
Status: $status
Sections Completed: $completedSections/6
Photos: ${inspection.imagePaths.length}
Videos: ${inspection.videoPaths.length}
Sync Status: ${inspection.isSynced ? 'Synced' : 'Pending'}

Permit Summary:
- Building Permit: ${_permitStatusText(inspection.hasBuildingPermit)}
  Recommendation: ${_permitRecommendation(inspection.buildingPermitRecommendation)}
- Occupancy Permit: ${_permitStatusText(inspection.hasOccupancyPermit)}
  $occupancyAge
  Recommendation: ${_permitRecommendation(inspection.occupancyPermitRecommendation)}

Business ID:
${inspection.scannedData}

Location: ${inspection.latitude != null && inspection.longitude != null 
  ? 'Lat: ${inspection.latitude!.toStringAsFixed(6)}, Lng: ${inspection.longitude!.toStringAsFixed(6)}' 
  : 'Not available'}

---
Office of Building Official - Ormoc City
Generated by OBO Mobile Inspector App

For detailed inspection data, please refer to the mobile application.''';
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

      // Move to trash instead of permanent deletion
      final success = await TrashService.moveToTrash(inspection);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        // Refresh the inspections list
        await _loadInspections();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Inspection moved to trash. You can restore it from the Trash screen.'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Failed to move inspection to trash');
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
            content: Text('Failed to move inspection to trash: $e'),
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
