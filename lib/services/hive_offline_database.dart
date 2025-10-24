import 'package:hive_flutter/hive_flutter.dart';
import '../models/user.dart';
import '../models/assignment.dart';
import '../models/inspection.dart';

class HiveOfflineDatabase {
  static Box<User>? _userBox;
  static Box<Assignment>? _assignmentBox;
  static Box<Inspection>? _inspectionBox;
  static Box<Map>? _syncStatusBox;
  static bool _initialized = false;

  // Box names
  static const String _userBoxName = 'users';
  static const String _assignmentBoxName = 'assignments';
  static const String _inspectionBoxName = 'inspections';
  static const String _syncStatusBoxName = 'sync_status';

  // Initialize Hive
  static Future<void> initialize() async {
    if (_initialized) {
      print('Hive database already initialized');
      return;
    }

    try {
      print('Initializing Hive database...');
      
      // Initialize Hive
      await Hive.initFlutter();
      print('Hive.initFlutter() completed');

      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(UserAdapter());
        print('UserAdapter registered');
      } else {
        print('UserAdapter already registered');
      }
      
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(AssignmentAdapter());
        print('AssignmentAdapter registered');
      } else {
        print('AssignmentAdapter already registered');
      }
      
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(AssignmentStatisticsAdapter());
        print('AssignmentStatisticsAdapter registered');
      } else {
        print('AssignmentStatisticsAdapter already registered');
      }
      
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(InspectionAdapter());
        print('InspectionAdapter registered');
      } else {
        print('InspectionAdapter already registered');
      }

      // Open boxes
      print('Opening Hive boxes...');
      _userBox = await Hive.openBox<User>(_userBoxName);
      print('User box opened: ${_userBox?.name}');
      
      _assignmentBox = await Hive.openBox<Assignment>(_assignmentBoxName);
      print('Assignment box opened: ${_assignmentBox?.name}');
      
      _inspectionBox = await Hive.openBox<Inspection>(_inspectionBoxName);
      print('Inspection box opened: ${_inspectionBox?.name}');
      
      _syncStatusBox = await Hive.openBox<Map>(_syncStatusBoxName);
      print('Sync status box opened: ${_syncStatusBox?.name}');

      _initialized = true;
      print('Hive database initialized successfully');
      print('Box counts - Users: ${_userBox?.length}, Assignments: ${_assignmentBox?.length}, Sync: ${_syncStatusBox?.length}');
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
    try {
      if (!_initialized) {
        print('Hive saveUser: Database not initialized');
        return;
      }
      
      print('Hive saveUser: Saving user ${user.name} (ID: ${user.id})');
      await userBox.put('current_user', user);
      await updateSyncStatus(_userBoxName, DateTime.now().toIso8601String(), 'success');
      
      // Verify the user was saved
      final savedUser = userBox.get('current_user');
      print('Hive saveUser: User saved successfully');
      print('  - Saved user: ${savedUser?.name ?? 'null'} (ID: ${savedUser?.id ?? 'null'})');
      print('  - User box count after save: ${userBox.length}');
      print('  - User box keys after save: ${userBox.keys.toList()}');
    } catch (e) {
      print('Error in saveUser: $e');
      rethrow;
    }
  }

  static User? getCurrentUser() {
    try {
      if (!_initialized) {
        print('Hive getCurrentUser: Database not initialized');
        return null;
      }
      
      final user = userBox.get('current_user');
      print('Hive getCurrentUser: Retrieved user ${user?.name ?? 'null'} (ID: ${user?.id ?? 'null'})');
      print('  - User box count: ${userBox.length}');
      print('  - User box keys: ${userBox.keys.toList()}');
      return user;
    } catch (e) {
      print('Error in getCurrentUser: $e');
      return null;
    }
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
    await updateSyncStatus(_assignmentBoxName, DateTime.now().toIso8601String(), 'success');
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
  static Future<void> updateSyncStatus(String tableName, String lastSync, String status) async {
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
    try {
      if (!_initialized) {
        print('Hive hasOfflineData: Database not initialized');
        return false;
      }
      
      final user = getCurrentUser();
      final assignmentCount = assignmentBox.length;
      final userBoxCount = userBox.length;
      
      print('Hive hasOfflineData check:');
      print('  - Initialized: $_initialized');
      print('  - User: ${user?.name ?? 'null'} (ID: ${user?.id ?? 'null'})');
      print('  - User box count: $userBoxCount');
      print('  - Assignment count: $assignmentCount');
      print('  - User box keys: ${userBox.keys.toList()}');
      print('  - Assignment box keys: ${assignmentBox.keys.toList()}');
      
      // More flexible check: either user OR assignments (or both)
      // This handles cases where sync might have saved user but no assignments yet
      final hasUser = user != null;
      final hasAssignments = assignmentCount > 0;
      final hasAnyData = hasUser || hasAssignments;
      
      print('  - Has user: $hasUser');
      print('  - Has assignments: $hasAssignments');
      print('  - Has any data: $hasAnyData');
      
      return hasAnyData;
    } catch (e) {
      print('Error in hasOfflineData: $e');
      return false;
    }
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

  // Inspection storage methods
  static Future<void> saveInspection(Inspection inspection) async {
    if (_inspectionBox == null) {
      print('Inspection box not initialized');
      return;
    }
    
    try {
      await _inspectionBox!.put(inspection.id, inspection);
      print('Inspection saved: ${inspection.id}');
    } catch (e) {
      print('Error saving inspection: $e');
    }
  }

  static List<Inspection> getInspections() {
    if (_inspectionBox == null) {
      print('Inspection box not initialized');
      return [];
    }
    
    try {
      return _inspectionBox!.values.toList();
    } catch (e) {
      print('Error getting inspections: $e');
      return [];
    }
  }

  static Inspection? getInspection(String id) {
    if (_inspectionBox == null) {
      print('Inspection box not initialized');
      return null;
    }
    
    try {
      return _inspectionBox!.get(id);
    } catch (e) {
      print('Error getting inspection: $e');
      return null;
    }
  }

  static Future<void> deleteInspection(String id) async {
    if (_inspectionBox == null) {
      print('Inspection box not initialized');
      return;
    }
    
    try {
      await _inspectionBox!.delete(id);
      print('Inspection deleted: $id');
    } catch (e) {
      print('Error deleting inspection: $e');
    }
  }

  static List<Inspection> getUnsyncedInspections() {
    if (_inspectionBox == null) {
      print('Inspection box not initialized');
      return [];
    }
    
    try {
      return _inspectionBox!.values.where((inspection) => !inspection.isSynced).toList();
    } catch (e) {
      print('Error getting unsynced inspections: $e');
      return [];
    }
  }

  static Future<void> markInspectionAsSynced(String id) async {
    if (_inspectionBox == null) {
      print('Inspection box not initialized');
      return;
    }
    
    try {
      final inspection = _inspectionBox!.get(id);
      if (inspection != null) {
        inspection.markAsSynced();
        await _inspectionBox!.put(id, inspection);
        print('Inspection marked as synced: $id');
      }
    } catch (e) {
      print('Error marking inspection as synced: $e');
    }
  }
}
