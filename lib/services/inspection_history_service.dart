import 'package:hive_flutter/hive_flutter.dart';
import '../models/inspection.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class InspectionHistoryService {
  static const String _historyBoxName = 'inspection_history';
  static Box<Map>? _historyBox;

  /// Initialize history box
  static Future<void> initialize() async {
    if (_historyBox != null) return;

    try {
      _historyBox = await Hive.openBox<Map>(_historyBoxName);
      print('Inspection history box initialized');
    } catch (e) {
      print('Error initializing inspection history box: $e');
    }
  }

  /// Log inspection creation
  static Future<void> logCreation(Inspection inspection) async {
    try {
      await initialize();
      final user = await AuthService.getCurrentUser();
      final history = {
        'id': 'history_${DateTime.now().millisecondsSinceEpoch}_${inspection.id}',
        'inspectionId': inspection.id,
        'action': 'created',
        'userId': user?.id,
        'userName': user?.name,
        'timestamp': DateTime.now().toIso8601String(),
        'description': 'Inspection created for Business ID: ${inspection.scannedData}',
      };
      
      await _saveHistory(history);
    } catch (e) {
      print('Error logging inspection creation: $e');
    }
  }

  /// Log inspection update
  static Future<void> logUpdate(
    Inspection inspection, {
    String? fieldName,
    String? oldValue,
    String? newValue,
    String? description,
    Map<String, dynamic>? changes,
  }) async {
    try {
      await initialize();
      final user = await AuthService.getCurrentUser();
      final history = {
        'id': 'history_${DateTime.now().millisecondsSinceEpoch}_${inspection.id}',
        'inspectionId': inspection.id,
        'action': 'updated',
        'userId': user?.id,
        'userName': user?.name,
        'timestamp': DateTime.now().toIso8601String(),
        'fieldName': fieldName,
        'oldValue': oldValue,
        'newValue': newValue,
        'description': description ?? 'Inspection updated',
        'changes': changes,
      };
      
      await _saveHistory(history);
    } catch (e) {
      print('Error logging inspection update: $e');
    }
  }

  /// Log status change
  static Future<void> logStatusChange(
    Inspection inspection,
    String section,
    String oldStatus,
    String newStatus,
  ) async {
    try {
      await initialize();
      final user = await AuthService.getCurrentUser();
      final history = {
        'id': 'history_${DateTime.now().millisecondsSinceEpoch}_${inspection.id}',
        'inspectionId': inspection.id,
        'action': 'status_changed',
        'userId': user?.id,
        'userName': user?.name,
        'timestamp': DateTime.now().toIso8601String(),
        'fieldName': section,
        'oldValue': oldStatus,
        'newValue': newStatus,
        'description': '$section status changed from $oldStatus to $newStatus',
      };
      
      await _saveHistory(history);
    } catch (e) {
      print('Error logging status change: $e');
    }
  }

  /// Log sync event
  static Future<void> logSync(Inspection inspection, bool success, {String? error}) async {
    try {
      await initialize();
      final user = await AuthService.getCurrentUser();
      final history = {
        'id': 'history_${DateTime.now().millisecondsSinceEpoch}_${inspection.id}',
        'inspectionId': inspection.id,
        'action': success ? 'synced' : 'sync_failed',
        'userId': user?.id,
        'userName': user?.name,
        'timestamp': DateTime.now().toIso8601String(),
        'description': success 
            ? 'Inspection synced to server successfully'
            : 'Sync failed: ${error ?? "Unknown error"}',
        'newValue': success ? 'synced' : 'failed',
      };
      
      await _saveHistory(history);
    } catch (e) {
      print('Error logging sync event: $e');
    }
  }

  /// Log media addition
  static Future<void> logMediaAdded(
    Inspection inspection,
    String mediaType, // 'photo' or 'video'
    String section,
    int count,
  ) async {
    try {
      await initialize();
      final user = await AuthService.getCurrentUser();
      final history = {
        'id': 'history_${DateTime.now().millisecondsSinceEpoch}_${inspection.id}',
        'inspectionId': inspection.id,
        'action': 'media_added',
        'userId': user?.id,
        'userName': user?.name,
        'timestamp': DateTime.now().toIso8601String(),
        'fieldName': section,
        'description': 'Added $count $mediaType${count > 1 ? 's' : ''} to $section section',
        'newValue': '$mediaType:$count',
      };
      
      await _saveHistory(history);
    } catch (e) {
      print('Error logging media addition: $e');
    }
  }

  /// Get all history for an inspection
  static Future<List<Map<String, dynamic>>> getInspectionHistory(String inspectionId) async {
    try {
      await initialize();
      if (_historyBox == null) return [];

      final allHistory = _historyBox!.values.toList();
      final inspectionHistory = allHistory
          .where((h) => h['inspectionId'] == inspectionId)
          .map((h) => Map<String, dynamic>.from(h))
          .toList();
      
      // Sort by timestamp (newest first)
      inspectionHistory.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      
      return inspectionHistory;
    } catch (e) {
      print('Error getting inspection history: $e');
      return [];
    }
  }

  /// Get recent history (last N entries)
  static Future<List<Map<String, dynamic>>> getRecentHistory({int limit = 50}) async {
    try {
      await initialize();
      if (_historyBox == null) return [];

      final allHistory = _historyBox!.values
          .map((h) => Map<String, dynamic>.from(h))
          .toList();
      
      allHistory.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      
      return allHistory.take(limit).toList();
    } catch (e) {
      print('Error getting recent history: $e');
      return [];
    }
  }

  /// Clear history for an inspection
  static Future<void> clearInspectionHistory(String inspectionId) async {
    try {
      await initialize();
      if (_historyBox == null) return;

      final keysToDelete = <String>[];
      // Iterate over keys and check the inspectionId in each value
      for (final key in _historyBox!.keys) {
        final history = _historyBox!.get(key);
        if (history != null && history['inspectionId'] == inspectionId) {
          keysToDelete.add(key.toString());
        }
      }

      for (final key in keysToDelete) {
        await _historyBox!.delete(key);
      }
    } catch (e) {
      print('Error clearing inspection history: $e');
    }
  }

  /// Save history entry
  static Future<void> _saveHistory(Map<String, dynamic> history) async {
    try {
      await initialize();
      if (_historyBox == null) return;

      await _historyBox!.put(history['id'], history);
    } catch (e) {
      print('Error saving history: $e');
    }
  }

  /// Get history box
  static Box<Map>? get historyBox => _historyBox;
}

