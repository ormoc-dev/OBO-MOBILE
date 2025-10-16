import '../models/assignment.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'offline_storage.dart';
import 'offline_sync_service.dart';
import 'connectivity_service.dart';

class AssignmentService {
  /// Get assigned inspections for the current user
  static Future<AssignmentResponse> getAssignments({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Get current user
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      final connectivityService = ConnectivityService();
      
      // Check if online
      if (connectivityService.isConnected) {
        // Online - fetch from API and cache
        try {
          // Build query parameters
          final queryParams = <String, String>{
            'user_id': user.id.toString(),
            'limit': limit.toString(),
            'offset': offset.toString(),
          };
          
          if (status != null && status.isNotEmpty) {
            queryParams['status'] = status;
          }
          
          // Build query string
          final queryString = queryParams.entries
              .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
              .join('&');
          
          final endpoint = '/mobile/get_assignments_simple.php${queryString.isNotEmpty ? '?$queryString' : ''}';
          
          final response = await ApiService.get(endpoint);
          final responseData = ApiService.handleResponse(response);
          
          final assignmentResponse = AssignmentResponse.fromJson(responseData);
          
          // Cache assignments if successful
          if (assignmentResponse.success && assignmentResponse.data != null) {
            await OfflineStorage.saveAssignments(assignmentResponse.data!.assignments);
          }
          
          return assignmentResponse;
        } catch (e) {
          // If online fetch fails, try offline
          return await _getOfflineAssignments(status: status);
        }
      } else {
        // Offline - get from sync data first, then fallback to old cache
        try {
          return await _getOfflineSyncAssignments(status: status);
        } catch (e) {
          // Fallback to old offline storage
          return await _getOfflineAssignments(status: status);
        }
      }
    } catch (e) {
      throw Exception('Failed to get assignments: $e');
    }
  }

  /// Get assignments from offline sync data
  static Future<AssignmentResponse> _getOfflineSyncAssignments({String? status}) async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      final allAssignments = await OfflineSyncService.getAllAssignmentsOffline();
      
      // Filter assignments for current user (you may need to adjust this logic)
      final userAssignments = allAssignments; // For now, return all assignments
      
      // Filter by status if provided
      final filteredAssignments = status != null && status.isNotEmpty
          ? userAssignments.where((a) => a.status == status).toList()
          : userAssignments;
      
      // Calculate statistics
      final statistics = AssignmentStatistics(
        totalAssignments: userAssignments.length,
        pendingAssignments: userAssignments.where((a) => a.status == 'assigned').length,
        inProgressAssignments: userAssignments.where((a) => a.status == 'in_progress').length,
        completedAssignments: userAssignments.where((a) => a.status == 'completed').length,
        cancelledAssignments: userAssignments.where((a) => a.status == 'cancelled').length,
      );
      
      return AssignmentResponse(
        success: true,
        message: 'Offline sync data loaded',
        data: AssignmentData(
          assignments: filteredAssignments,
          statistics: statistics,
          pagination: AssignmentPagination(
            limit: 50,
            offset: 0,
            total: statistics.totalAssignments,
          ),
        ),
      );
    } catch (e) {
      throw Exception('Failed to load offline sync assignments: $e');
    }
  }

  /// Get assignments from offline storage (fallback)
  static Future<AssignmentResponse> _getOfflineAssignments({String? status}) async {
    try {
      final assignments = await OfflineStorage.getAssignments(status: status);
      final statistics = await OfflineStorage.getAssignmentStatistics();
      
      return AssignmentResponse(
        success: true,
        message: 'Offline data loaded',
        data: AssignmentData(
          assignments: assignments,
          statistics: statistics,
          pagination: AssignmentPagination(
            limit: 50,
            offset: 0,
            total: statistics.totalAssignments,
          ),
        ),
      );
    } catch (e) {
      throw Exception('Failed to load offline assignments: $e');
    }
  }

  /// Get pending assignments
  static Future<AssignmentResponse> getPendingAssignments({
    int limit = 50,
    int offset = 0,
  }) async {
    return getAssignments(
      status: 'assigned',
      limit: limit,
      offset: offset,
    );
  }

  /// Get in-progress assignments
  static Future<AssignmentResponse> getInProgressAssignments({
    int limit = 50,
    int offset = 0,
  }) async {
    return getAssignments(
      status: 'in_progress',
      limit: limit,
      offset: offset,
    );
  }

  /// Get completed assignments
  static Future<AssignmentResponse> getCompletedAssignments({
    int limit = 50,
    int offset = 0,
  }) async {
    return getAssignments(
      status: 'completed',
      limit: limit,
      offset: offset,
    );
  }
}
