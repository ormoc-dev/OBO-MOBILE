import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/assignment.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'auth_service.dart';
import 'hive_offline_database.dart';

class OfflineSyncService {
  static const String _usersKey = 'offline_users';
  static const String _assignmentsKey = 'offline_assignments';
  static const String _lastSyncKey = 'last_sync_time';
  static const String _syncStatusKey = 'sync_status';

  /// Fetch user-specific data from server and store offline
  static Future<SyncResult> fetchUserData() async {
    try {
      final connectivityService = ConnectivityService();
      
      if (!connectivityService.isConnected) {
        return SyncResult(
          success: false,
          message: 'No internet connection. Please connect to internet first.',
        );
      }

      // Get current user to fetch their specific data
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return SyncResult(
          success: false,
          message: 'No user logged in. Please login first.',
        );
      }

      // Fetch user's assignments based on their inspector_role_id
      // For head_inspector role, don't pass inspector_role_id parameter
      String apiUrl = '/mobile/get_user_assignments.php?user_id=${currentUser.id}';
      if (currentUser.inspectorRole != null && currentUser.inspectorRole!.isNotEmpty) {
        apiUrl += '&inspector_role_id=${currentUser.inspectorRole}';
      }
      final assignmentsResponse = await ApiService.get(apiUrl);
      final assignmentsData = ApiService.handleResponse(assignmentsResponse);
      
      if (!assignmentsData['success']) {
        return SyncResult(
          success: false,
          message: 'Failed to fetch assignments: ${assignmentsData['message']}',
        );
      }

      // Store current user offline using Hive
      print('OfflineSync: Storing user ${currentUser.name}');
      await HiveOfflineDatabase.saveUser(currentUser);
      
      // Verify user was saved
      final savedUser = HiveOfflineDatabase.getCurrentUser();
      print('OfflineSync: User saved verification - ${savedUser?.name ?? 'null'} (ID: ${savedUser?.id ?? 'null'})');

      // Store user's assignments offline using Hive
      final assignments = (assignmentsData['data']['assignments'] as List)
          .map((json) => Assignment.fromJson(json))
          .toList();
      print('OfflineSync: Storing ${assignments.length} assignments');
      await HiveOfflineDatabase.saveAssignments(assignments);
      
      // Verify assignments were saved
      final savedAssignments = HiveOfflineDatabase.getAssignments();
      print('OfflineSync: Assignments saved verification - ${savedAssignments.length} assignments');
      
      // Check if data is now available offline
      final hasData = HiveOfflineDatabase.hasOfflineData();
      print('OfflineSync: Has offline data after save: $hasData');

      // Store user credentials for offline login
      await _storeUserCredentials(currentUser);

      // Update sync status
      await _updateSyncStatus(true, DateTime.now().toIso8601String());

      return SyncResult(
        success: true,
        message: 'Successfully synced ${assignments.length} assignments and credentials for ${currentUser.name}',
        usersCount: 1, // Only current user
        assignmentsCount: assignments.length,
      );

    } catch (e) {
      await _updateSyncStatus(false, DateTime.now().toIso8601String());
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
      );
    }
  }

  /// Fetch all users and assignments from server and store offline (Admin only)
  static Future<SyncResult> fetchAllData() async {
    try {
      final connectivityService = ConnectivityService();
      
      if (!connectivityService.isConnected) {
        return SyncResult(
          success: false,
          message: 'No internet connection. Please connect to internet first.',
        );
      }

      // Check if current user is admin
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser?.role?.toLowerCase() != 'admin') {
        return SyncResult(
          success: false,
          message: 'Admin access required. Use "Sync My Data" instead.',
        );
      }

      // At this point, currentUser is guaranteed to be non-null due to the admin check above
      final adminUser = currentUser!;

      // Fetch all users (admin endpoint)
      final usersResponse = await ApiService.get('/mobile/get_all_users.php?user_id=${adminUser.id}');
      final usersData = ApiService.handleResponse(usersResponse);
      
      if (!usersData['success']) {
        return SyncResult(
          success: false,
          message: 'Failed to fetch users: ${usersData['message']}',
        );
      }

      // Fetch all assignments (admin endpoint)
      final assignmentsResponse = await ApiService.get('/mobile/get_all_assignments.php?user_id=${adminUser.id}');
      final assignmentsData = ApiService.handleResponse(assignmentsResponse);
      
      if (!assignmentsData['success']) {
        return SyncResult(
          success: false,
          message: 'Failed to fetch assignments: ${assignmentsData['message']}',
        );
      }

      // Store users offline using Hive
      final users = (usersData['data']['users'] as List)
          .map((json) => User.fromJson(json))
          .toList();
      await HiveOfflineDatabase.saveUser(adminUser); // Save admin user

      // Store assignments offline using Hive
      final assignments = (assignmentsData['data']['assignments'] as List)
          .map((json) => Assignment.fromJson(json))
          .toList();
      await HiveOfflineDatabase.saveAssignments(assignments);

      // Update sync status
      await _updateSyncStatus(true, DateTime.now().toIso8601String());

      return SyncResult(
        success: true,
        message: 'Successfully synced ${users.length} users and ${assignments.length} assignments',
        usersCount: users.length,
        assignmentsCount: assignments.length,
      );

    } catch (e) {
      await _updateSyncStatus(false, DateTime.now().toIso8601String());
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
      );
    }
  }


  /// Store assignments offline
  static Future<void> _storeAssignmentsOffline(List<Assignment> assignments) async {
    final prefs = await SharedPreferences.getInstance();
    final assignmentsJson = jsonEncode(assignments.map((a) => a.toJson()).toList());
    await prefs.setString(_assignmentsKey, assignmentsJson);
  }

  /// Store user credentials for offline login
  static Future<void> _storeUserCredentials(User user) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Store user credentials securely
    final credentials = {
      'username': user.name,
      'user_id': user.id,
      'inspector_role_id': user.inspectorRole,
      'role': user.role,
      'status': user.status,
      'synced_at': DateTime.now().toIso8601String(),
    };
    
    await prefs.setString('offline_credentials', jsonEncode(credentials));
  }

  /// Get all users from offline storage
  static Future<List<User>> getAllUsersOffline() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);
      if (usersJson != null) {
        try {
          final List<dynamic> usersList = jsonDecode(usersJson);
          return usersList
              .map((json) => User.fromJson(json as Map<String, dynamic>))
              .toList();
        } catch (e) {
          print('Error parsing users data: $e');
        }
      }
    } else {
      // Use Hive for mobile
      final user = HiveOfflineDatabase.getCurrentUser();
      return user != null ? [user] : [];
    }
    return [];
  }

  /// Get all assignments from offline storage
  static Future<List<Assignment>> getAllAssignmentsOffline() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final assignmentsJson = prefs.getString(_assignmentsKey);
      if (assignmentsJson != null) {
        try {
          final List<dynamic> assignmentsList = jsonDecode(assignmentsJson);
          return assignmentsList
              .map((json) => Assignment.fromJson(json as Map<String, dynamic>))
              .toList();
        } catch (e) {
          print('Error parsing assignments data: $e');
        }
      }
    } else {
      // Use Hive for mobile
      return HiveOfflineDatabase.getAssignments();
    }
    return [];
  }

  /// Get assignments for specific user offline
  static Future<List<Assignment>> getUserAssignmentsOffline(int userId) async {
    final allAssignments = await getAllAssignmentsOffline();
    return allAssignments.where((assignment) {
      // This assumes assignments have a user_id field or similar
      // You may need to adjust this based on your assignment structure
      return true; // For now, return all assignments
    }).toList();
  }

  /// Authenticate user offline
  static Future<User?> authenticateOffline(String username, String password) async {
    try {
      // First, try to get user from stored credentials
      final prefs = await SharedPreferences.getInstance();
      final credentialsJson = prefs.getString('offline_credentials');
      
      if (credentialsJson != null) {
        final credentials = jsonDecode(credentialsJson);
        
        // Check if username matches stored credentials
        if (credentials['username']?.toLowerCase() == username.toLowerCase()) {
          // Create user object from stored credentials
          final user = User(
            id: credentials['user_id'],
            name: credentials['username'],
            role: credentials['role'],
            inspectorRole: credentials['inspector_role_id'],
            status: credentials['status'],
          );
          
          // In a real app, you'd verify password hash
          // For now, we'll assume the user exists in offline storage
          return user;
        }
      }
      
      // Fallback to old method for backward compatibility
      final users = await getAllUsersOffline();
      final user = users.where((u) => u.name.toLowerCase() == username.toLowerCase()).firstOrNull;
      
      if (user != null) {
        return user;
      }
      
      return null;
    } catch (e) {
      print('Error in offline authentication: $e');
      return null;
    }
  }

  /// Update assignment status offline
  static Future<bool> updateAssignmentStatusOffline(int assignmentId, String newStatus) async {
    try {
      final assignments = await getAllAssignmentsOffline();
      final assignmentIndex = assignments.indexWhere((a) => a.assignmentId == assignmentId);
      
      if (assignmentIndex != -1) {
        // Create updated assignment
        final updatedAssignment = Assignment(
          assignmentId: assignments[assignmentIndex].assignmentId,
          status: newStatus,
          inspectionDate: assignments[assignmentIndex].inspectionDate,
          completionDate: newStatus == 'completed' ? DateTime.now().toIso8601String() : assignments[assignmentIndex].completionDate,
          assignedAt: assignments[assignmentIndex].assignedAt,
          assignmentNotes: assignments[assignmentIndex].assignmentNotes,
          businessAssignmentId: assignments[assignmentIndex].businessAssignmentId,
          businessId: assignments[assignmentIndex].businessId,
          businessName: assignments[assignmentIndex].businessName,
          businessAddress: assignments[assignmentIndex].businessAddress,
          businessNotes: assignments[assignmentIndex].businessNotes,
          departmentName: assignments[assignmentIndex].departmentName,
          departmentDescription: assignments[assignmentIndex].departmentDescription,
          assignedByName: assignments[assignmentIndex].assignedByName,
          assignedByAdmin: assignments[assignmentIndex].assignedByAdmin,
        );
        
        assignments[assignmentIndex] = updatedAssignment;
        await _storeAssignmentsOffline(assignments);
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating assignment offline: $e');
      return false;
    }
  }

  /// Sync offline changes when online
  static Future<SyncResult> syncOfflineChanges() async {
    try {
      final connectivityService = ConnectivityService();
      
      if (!connectivityService.isConnected) {
        return SyncResult(
          success: false,
          message: 'No internet connection for sync',
        );
      }

      // Here you would implement logic to sync offline changes back to server
      // For now, we'll just refetch all data
      return await fetchAllData();

    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
      );
    }
  }

  /// Get sync status
  static Future<SyncStatus> getSyncStatus() async {
    if (kIsWeb) {
      // Use SharedPreferences for web
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString(_lastSyncKey);
      final syncStatusString = prefs.getString(_syncStatusKey);
      
      DateTime? lastSync;
      bool isSuccess = false;
      
      if (lastSyncString != null) {
        lastSync = DateTime.tryParse(lastSyncString);
      }
      
      if (syncStatusString != null) {
        isSuccess = syncStatusString == 'success';
      }
      
      return SyncStatus(
        lastSync: lastSync,
        isSuccess: isSuccess,
        hasData: await hasOfflineData(),
      );
    } else {
      // Use Hive for mobile
      try {
        final userSyncData = HiveOfflineDatabase.getLastSyncTime('users');
        final assignmentSyncData = HiveOfflineDatabase.getLastSyncTime('assignments');
        
        print('SyncStatus from Hive:');
        print('  - User sync: ${userSyncData?.toString() ?? 'null'}');
        print('  - Assignment sync: ${assignmentSyncData?.toString() ?? 'null'}');
        
        // Use the most recent sync time
        DateTime? lastSync;
        bool isSuccess = false;
        
        if (userSyncData != null && assignmentSyncData != null) {
          // Use the more recent sync time
          lastSync = userSyncData.isAfter(assignmentSyncData) ? userSyncData : assignmentSyncData;
          isSuccess = true;
        } else if (userSyncData != null) {
          lastSync = userSyncData;
          isSuccess = true;
        } else if (assignmentSyncData != null) {
          lastSync = assignmentSyncData;
          isSuccess = true;
        }
        
        print('OfflineSyncService getSyncStatus: About to call hasOfflineData()');
        final hasData = await hasOfflineData();
        print('OfflineSyncService getSyncStatus: hasOfflineData() returned $hasData');
        print('  - Last sync: ${lastSync?.toString() ?? 'null'}');
        print('  - Is success: $isSuccess');
        print('  - Has data: $hasData');
        
        return SyncStatus(
          lastSync: lastSync,
          isSuccess: isSuccess,
          hasData: hasData,
        );
      } catch (e) {
        print('Error getting sync status from Hive: $e');
        return SyncStatus(
          lastSync: null,
          isSuccess: false,
          hasData: false,
        );
      }
    }
  }

  /// Check if offline data exists
  static Future<bool> hasOfflineData() async {
    try {
      print('OfflineSyncService hasOfflineData: kIsWeb=$kIsWeb');
      
      // For now, always use Hive since we know it's working
      // TODO: Fix platform detection if needed
      print('OfflineSyncService hasOfflineData: Using Hive directly');
      final result = HiveOfflineDatabase.hasOfflineData();
      print('OfflineSyncService hasOfflineData: Hive result=$result');
      return result;
      
      // Original logic (commented out for debugging)
      /*
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final hasUsers = prefs.containsKey(_usersKey);
        final hasAssignments = prefs.containsKey(_assignmentsKey);
        print('OfflineSyncService hasOfflineData (Web): hasUsers=$hasUsers, hasAssignments=$hasAssignments');
        return hasUsers && hasAssignments;
      } else {
        // Use Hive for mobile
        print('OfflineSyncService hasOfflineData (Mobile): calling HiveOfflineDatabase.hasOfflineData()');
        final result = HiveOfflineDatabase.hasOfflineData();
        print('OfflineSyncService hasOfflineData (Mobile): result=$result');
        return result;
      }
      */
    } catch (e) {
      print('OfflineSyncService hasOfflineData error: $e');
      return false;
    }
  }

  /// Check if offline credentials are available
  static Future<bool> hasOfflineCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('offline_credentials');
    } catch (e) {
      return false;
    }
  }

  /// Get stored offline credentials
  static Future<Map<String, dynamic>?> getOfflineCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsJson = prefs.getString('offline_credentials');
      
      if (credentialsJson != null) {
        return jsonDecode(credentialsJson);
      }
      return null;
    } catch (e) {
      print('Error getting offline credentials: $e');
      return null;
    }
  }

  /// Update sync status
  static Future<void> _updateSyncStatus(bool success, String timestamp) async {
    if (kIsWeb) {
      // Use SharedPreferences for web
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, timestamp);
      await prefs.setString(_syncStatusKey, success ? 'success' : 'failed');
    } else {
      // Use Hive for mobile - update sync status in Hive
      try {
        await HiveOfflineDatabase.updateSyncStatus('users', timestamp, success ? 'success' : 'failed');
        await HiveOfflineDatabase.updateSyncStatus('assignments', timestamp, success ? 'success' : 'failed');
        print('Sync status updated in Hive: success=$success, timestamp=$timestamp');
      } catch (e) {
        print('Error updating sync status in Hive: $e');
      }
    }
  }

  /// Clear all offline data
  static Future<void> clearAllOfflineData() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_usersKey);
      await prefs.remove(_assignmentsKey);
      await prefs.remove(_lastSyncKey);
      await prefs.remove(_syncStatusKey);
      await prefs.remove('offline_credentials');
    } else {
      // Use Hive for mobile
      await HiveOfflineDatabase.clearAllData();
      // Also clear credentials from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_credentials');
    }
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int? usersCount;
  final int? assignmentsCount;

  SyncResult({
    required this.success,
    required this.message,
    this.usersCount,
    this.assignmentsCount,
  });
}

class SyncStatus {
  final DateTime? lastSync;
  final bool isSuccess;
  final bool hasData;

  SyncStatus({
    this.lastSync,
    required this.isSuccess,
    required this.hasData,
  });
}


