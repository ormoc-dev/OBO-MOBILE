import 'package:hive_flutter/hive_flutter.dart';
import '../models/user.dart';
import '../models/assignment.dart';

class HiveOfflineDatabase {
  static Box<User>? _userBox;
  static Box<Assignment>? _assignmentBox;
  static Box<Map>? _syncStatusBox;
  static bool _initialized = false;

  // Box names
  static const String _userBoxName = 'users';
  static const String _assignmentBoxName = 'assignments';
  static const String _syncStatusBoxName = 'sync_status';

  // Initialize Hive
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Hive
      await Hive.initFlutter();

      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(UserAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(AssignmentAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(AssignmentStatisticsAdapter());
      }

      // Open boxes
      _userBox = await Hive.openBox<User>(_userBoxName);
      _assignmentBox = await Hive.openBox<Assignment>(_assignmentBoxName);
      _syncStatusBox = await Hive.openBox<Map>(_syncStatusBoxName);

      _initialized = true;
      print('Hive database initialized successfully');
    } catch (e) {
      print('Error initializing Hive database: $e');
      rethrow;
    }
  }

  // Get boxes
  static Box<User> get userBox {
    if (_userBox == null) throw Exception('Database not initialized. Call initialize() first.');
    return _userBox!;
  }

  static Box<Assignment> get assignmentBox {
    if (_assignmentBox == null) throw Exception('Database not initialized. Call initialize() first.');
    return _assignmentBox!;
  }

  static Box<Map> get syncStatusBox {
    if (_syncStatusBox == null) throw Exception('Database not initialized. Call initialize() first.');
    return _syncStatusBox!;
  }

  // User operations
  static Future<void> saveUser(User user) async {
    print('Hive saveUser: Saving user ${user.name} (ID: ${user.id})');
    await userBox.put('current_user', user);
    await _updateSyncStatus(_userBoxName, DateTime.now().toIso8601String(), 'success');
    print('Hive saveUser: User saved successfully');
  }

  static User? getCurrentUser() {
    return userBox.get('current_user');
  }

  static Future<void> clearUser() async {
    await userBox.clear();
  }

  // Assignment operations
  static Future<void> saveAssignments(List<Assignment> assignments) async {
    print('Hive saveAssignments: Saving ${assignments.length} assignments');
    
    // Clear existing assignments
    await assignmentBox.clear();
    
    // Save new assignments with assignment_id as key
    for (final assignment in assignments) {
      await assignmentBox.put(assignment.assignmentId, assignment);
      print('  - Saved assignment: ${assignment.assignmentId} - ${assignment.businessName}');
    }
    
    print('Hive saveAssignments: Total assignments in box: ${assignmentBox.length}');
    
    // Update sync status
    await _updateSyncStatus(_assignmentBoxName, DateTime.now().toIso8601String(), 'success');
  }

  static List<Assignment> getAssignments({String? status}) {
    final assignments = assignmentBox.values.toList();
    
    if (status != null && status.isNotEmpty) {
      return assignments.where((assignment) => assignment.status == status).toList();
    }
    
    // Sort by assigned_at date (most recent first)
    assignments.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
    return assignments;
  }

  static AssignmentStatistics getAssignmentStatistics() {
    final assignments = assignmentBox.values.toList();
    
    int totalAssignments = assignments.length;
    int pendingAssignments = assignments.where((a) => a.status == 'assigned').length;
    int inProgressAssignments = assignments.where((a) => a.status == 'in_progress').length;
    int completedAssignments = assignments.where((a) => a.status == 'completed').length;
    int cancelledAssignments = assignments.where((a) => a.status == 'cancelled').length;

    return AssignmentStatistics(
      totalAssignments: totalAssignments,
      pendingAssignments: pendingAssignments,
      inProgressAssignments: inProgressAssignments,
      completedAssignments: completedAssignments,
      cancelledAssignments: cancelledAssignments,
    );
  }

  // Sync status operations
  static Future<void> _updateSyncStatus(String tableName, String lastSync, String status) async {
    await syncStatusBox.put(tableName, {
      'table_name': tableName,
      'last_sync': lastSync,
      'sync_status': status,
    });
  }

  static DateTime? getLastSyncTime(String tableName) {
    final syncData = syncStatusBox.get(tableName);
    if (syncData != null && syncData['last_sync'] != null) {
      return DateTime.tryParse(syncData['last_sync']);
    }
    return null;
  }

  // Check if data is available offline
  static bool hasOfflineData() {
    final user = getCurrentUser();
    final assignmentCount = assignmentBox.length;
    
    print('Hive hasOfflineData check:');
    print('  - User: ${user?.name ?? 'null'}');
    print('  - Assignment count: $assignmentCount');
    print('  - Has data: ${user != null && assignmentCount > 0}');
    
    return user != null && assignmentCount > 0;
  }

  // Clear all offline data
  static Future<void> clearAllData() async {
    await userBox.clear();
    await assignmentBox.clear();
    await syncStatusBox.clear();
  }

  // Close all boxes
  static Future<void> close() async {
    await _userBox?.close();
    await _assignmentBox?.close();
    await _syncStatusBox?.close();
    _initialized = false;
  }

  // Get database size info
  static Map<String, int> getDatabaseInfo() {
    return {
      'users': userBox.length,
      'assignments': assignmentBox.length,
      'sync_status': syncStatusBox.length,
    };
  }

  // Backup and restore functionality
  static Future<Map<String, dynamic>> exportData() async {
    return {
      'users': userBox.values.map((user) => user.toJson()).toList(),
      'assignments': assignmentBox.values.map((assignment) => assignment.toJson()).toList(),
      'sync_status': syncStatusBox.toMap(),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    // Import users
    if (data['users'] != null) {
      await userBox.clear();
      for (final userData in data['users']) {
        final user = User.fromJson(userData);
        await userBox.put('current_user', user);
      }
    }

    // Import assignments
    if (data['assignments'] != null) {
      await assignmentBox.clear();
      for (final assignmentData in data['assignments']) {
        final assignment = Assignment.fromJson(assignmentData);
        await assignmentBox.put(assignment.assignmentId, assignment);
      }
    }

    // Import sync status
    if (data['sync_status'] != null) {
      await syncStatusBox.clear();
      for (final entry in (data['sync_status'] as Map).entries) {
        await syncStatusBox.put(entry.key, entry.value);
      }
    }
  }
}
