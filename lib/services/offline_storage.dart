import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/assignment.dart';
import 'hive_offline_database.dart';

class OfflineStorage {
  static const String _userKey = 'offline_user';
  static const String _assignmentsKey = 'offline_assignments';
  static const String _statisticsKey = 'offline_statistics';
  static const String _lastSyncKey = 'last_sync_time';

  // User operations
  static Future<void> saveUser(User user) async {
    if (kIsWeb) {
      // Use SharedPreferences for web
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } else {
      // Use Hive for mobile
      await HiveOfflineDatabase.saveUser(user);
    }
  }

  static Future<User?> getCurrentUser() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        try {
          final userMap = jsonDecode(userJson) as Map<String, dynamic>;
          return User.fromJson(userMap);
        } catch (e) {
          print('Error parsing user data: $e');
          return null;
        }
      }
    } else {
      // Use Hive for mobile
      return HiveOfflineDatabase.getCurrentUser();
    }
    return null;
  }

  static Future<void> clearUser() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } else {
      // Use Hive for mobile
      await HiveOfflineDatabase.clearUser();
    }
  }

  // Assignment operations
  static Future<void> saveAssignments(List<Assignment> assignments) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final assignmentsJson = jsonEncode(assignments.map((a) => a.toJson()).toList());
      await prefs.setString(_assignmentsKey, assignmentsJson);
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } else {
      // Use Hive for mobile
      await HiveOfflineDatabase.saveAssignments(assignments);
    }
  }

  static Future<List<Assignment>> getAssignments({String? status}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final assignmentsJson = prefs.getString(_assignmentsKey);
      if (assignmentsJson != null) {
        try {
          final List<dynamic> assignmentsList = jsonDecode(assignmentsJson);
          final assignments = assignmentsList
              .map((json) => Assignment.fromJson(json as Map<String, dynamic>))
              .toList();
          
          // Filter by status if provided
          if (status != null && status.isNotEmpty) {
            return assignments.where((a) => a.status == status).toList();
          }
          
          return assignments;
        } catch (e) {
          print('Error parsing assignments data: $e');
          return [];
        }
      }
    } else {
      // Use Hive for mobile
      return HiveOfflineDatabase.getAssignments(status: status);
    }
    return [];
  }

  static Future<AssignmentStatistics> getAssignmentStatistics() async {
    if (kIsWeb) {
      final assignments = await getAssignments();
      
      return AssignmentStatistics(
        totalAssignments: assignments.length,
        pendingAssignments: assignments.where((a) => a.status == 'assigned').length,
        inProgressAssignments: assignments.where((a) => a.status == 'in_progress').length,
        completedAssignments: assignments.where((a) => a.status == 'completed').length,
        cancelledAssignments: assignments.where((a) => a.status == 'cancelled').length,
      );
    } else {
      // Use Hive for mobile
      return HiveOfflineDatabase.getAssignmentStatistics();
    }
  }

  static Future<DateTime?> getLastSyncTime() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString(_lastSyncKey);
      if (lastSyncString != null) {
        return DateTime.tryParse(lastSyncString);
      }
    } else {
      // Use Hive for mobile
      return HiveOfflineDatabase.getLastSyncTime('assignments');
    }
    return null;
  }

  // Check if data is available offline
  static Future<bool> hasOfflineData() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final hasUser = prefs.containsKey(_userKey);
      final hasAssignments = prefs.containsKey(_assignmentsKey);
      return hasUser && hasAssignments;
    } else {
      // Use Hive for mobile
      return HiveOfflineDatabase.hasOfflineData();
    }
  }

  // Clear all offline data
  static Future<void> clearAllData() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_assignmentsKey);
      await prefs.remove(_statisticsKey);
      await prefs.remove(_lastSyncKey);
    } else {
      // Use Hive for mobile
      await HiveOfflineDatabase.clearAllData();
    }
  }
}
