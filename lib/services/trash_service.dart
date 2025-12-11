import 'package:hive_flutter/hive_flutter.dart';
import '../models/inspection.dart';
import '../services/auth_service.dart';
import '../services/hive_offline_database.dart';

class TrashService {
  static const String _trashBoxName = 'trash_inspections';
  static Box<Map>? _trashBox;

  /// Initialize trash box
  static Future<void> initialize() async {
    if (_trashBox != null) return;

    try {
      _trashBox = await Hive.openBox<Map>(_trashBoxName);
      print('Trash box initialized');
    } catch (e) {
      print('Error initializing trash box: $e');
    }
  }

  /// Move inspection to trash (soft delete)
  static Future<bool> moveToTrash(
    Inspection inspection, {
    String? reason,
  }) async {
    try {
      await initialize();
      if (_trashBox == null) return false;

      final user = await AuthService.getCurrentUser();
      final deletedItem = {
        'id': 'trash_${DateTime.now().millisecondsSinceEpoch}_${inspection.id}',
        'inspectionId': inspection.id,
        'inspection': inspection.toJson(),
        'deletedAt': DateTime.now().toIso8601String(),
        'deletedBy': user?.name ?? user?.id,
        'deletionReason': reason ?? '',
        'isPermanent': false,
      };

      await _trashBox!.put(deletedItem['id'], deletedItem);

      // Remove from main inspections box
      await HiveOfflineDatabase.inspectionBox.delete(inspection.id);

      print('Inspection ${inspection.id} moved to trash');
      return true;
    } catch (e) {
      print('Error moving inspection to trash: $e');
      return false;
    }
  }

  /// Restore inspection from trash
  static Future<bool> restoreFromTrash(String inspectionId) async {
    try {
      await initialize();
      if (_trashBox == null) return false;

      // Find deleted item
      DeletedItem? deletedItem;
      String? trashKey;

      for (final key in _trashBox!.keys) {
        final item = _trashBox!.get(key);
        if (item != null && item is Map) {
          final itemMap = Map<String, dynamic>.from(item);
          if (itemMap['inspectionId'] == inspectionId) {
            deletedItem = DeletedItem.fromMap(itemMap);
            trashKey = key.toString();
            break;
          }
        }
      }

      if (deletedItem == null || trashKey == null) {
        print('Inspection not found in trash: $inspectionId');
        return false;
      }

      if (deletedItem.isPermanent) {
        print('Cannot restore permanently deleted inspection: $inspectionId');
        return false;
      }

      // Recreate inspection object from stored JSON
      final inspectionJson = deletedItem.inspection;
      
      // Recreate inspection object from stored JSON using Inspection.fromFormData
      // Then update all fields to match the original
      final inspection = Inspection(
        id: inspectionJson['id'] ?? deletedItem.inspectionId,
        scannedData: inspectionJson['scanned_data'] ?? 'No QR data',
        mechanicalRemarks: inspectionJson['mechanical_remarks'] ?? '',
        mechanicalAssessment: inspectionJson['mechanical_assessment'] ?? '',
        lineGradeRemarks: inspectionJson['line_grade_remarks'] ?? '',
        lineGradeAssessment: inspectionJson['line_grade_assessment'] ?? '',
        architecturalRemarks: inspectionJson['architectural_remarks'] ?? '',
        architecturalAssessment: inspectionJson['architectural_assessment'] ?? '',
        civilStructuralRemarks: inspectionJson['civil_structural_remarks'] ?? '',
        civilStructuralAssessment: inspectionJson['civil_structural_assessment'] ?? '',
        sanitaryPlumbingRemarks: inspectionJson['sanitary_plumbing_remarks'] ?? '',
        sanitaryPlumbingAssessment: inspectionJson['sanitary_plumbing_assessment'] ?? '',
        electricalElectronicsRemarks: inspectionJson['electrical_electronics_remarks'] ?? '',
        electricalElectronicsAssessment: inspectionJson['electrical_electronics_assessment'] ?? '',
        createdAt: inspectionJson['created_at'] != null 
            ? DateTime.parse(inspectionJson['created_at']) 
            : DateTime.now(),
        updatedAt: DateTime.now(), // Update timestamp on restore
        isSynced: inspectionJson['is_synced'] ?? false,
        userId: inspectionJson['user_id']?.toString(),
        latitude: inspectionJson['latitude'] != null ? (inspectionJson['latitude'] is num ? (inspectionJson['latitude'] as num).toDouble() : double.tryParse(inspectionJson['latitude'].toString())) : null,
        longitude: inspectionJson['longitude'] != null ? (inspectionJson['longitude'] is num ? (inspectionJson['longitude'] as num).toDouble() : double.tryParse(inspectionJson['longitude'].toString())) : null,
        imagePaths: (inspectionJson['image_paths'] as List?)?.map((e) => e.toString()).toList() ?? [],
        videoPaths: (inspectionJson['video_paths'] as List?)?.map((e) => e.toString()).toList() ?? [],
        sectionImagePaths: inspectionJson['section_image_paths'] != null
            ? Map<String, List<String>>.from(
                (inspectionJson['section_image_paths'] as Map).map(
                  (key, value) => MapEntry(
                    key.toString(),
                    (value as List).map((e) => e.toString()).toList(),
                  ),
                ),
              )
            : null,
        sectionVideoPaths: inspectionJson['section_video_paths'] != null
            ? Map<String, List<String>>.from(
                (inspectionJson['section_video_paths'] as Map).map(
                  (key, value) => MapEntry(
                    key.toString(),
                    (value as List).map((e) => e.toString()).toList(),
                  ),
                ),
              )
            : null,
        inspectionStartTime: inspectionJson['inspection_start_time'] != null
            ? DateTime.tryParse(inspectionJson['inspection_start_time'].toString())
            : null,
        inspectionEndTime: inspectionJson['inspection_end_time'] != null
            ? DateTime.tryParse(inspectionJson['inspection_end_time'].toString())
            : null,
        sectionStatus: inspectionJson['section_status'] != null
            ? Map<String, String>.from(
                (inspectionJson['section_status'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                ),
              )
            : {},
        hasBuildingPermit: inspectionJson['has_building_permit'] as bool?,
        hasOccupancyPermit: inspectionJson['has_occupancy_permit'] as bool?,
        occupancyPermitIssuedYear: inspectionJson['occupancy_permit_issued_year'] != null
            ? (inspectionJson['occupancy_permit_issued_year'] is int 
                ? inspectionJson['occupancy_permit_issued_year'] as int
                : int.tryParse(inspectionJson['occupancy_permit_issued_year'].toString()))
            : null,
        occupancyPermitRecommendation: inspectionJson['occupancy_permit_recommendation']?.toString(),
        buildingPermitRecommendation: inspectionJson['building_permit_recommendation']?.toString(),
        buildingPermitId: inspectionJson['building_permit_id']?.toString(),
        occupancyPermitId: inspectionJson['occupancy_permit_id']?.toString(),
      );

      // Restore to main inspections box
      await HiveOfflineDatabase.saveInspection(inspection);

      // Remove from trash
      await _trashBox!.delete(trashKey);

      print('Inspection ${inspectionId} restored from trash');
      return true;
    } catch (e) {
      print('Error restoring inspection from trash: $e');
      return false;
    }
  }

  /// Get all deleted inspections
  static Future<List<DeletedItem>> getTrashItems() async {
    try {
      await initialize();
      if (_trashBox == null) return [];

      final items = _trashBox!.values
          .map((item) => DeletedItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      // Sort by deletion date (newest first)
      items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));

      return items;
    } catch (e) {
      print('Error getting trash items: $e');
      return [];
    }
  }

  /// Permanently delete from trash
  static Future<bool> permanentlyDelete(String inspectionId) async {
    try {
      await initialize();
      if (_trashBox == null) return false;

      // Find and mark as permanent
      for (final key in _trashBox!.keys) {
        final item = _trashBox!.get(key) as Map?;
        if (item != null && item['inspectionId'] == inspectionId) {
          item['isPermanent'] = true;
          await _trashBox!.put(key, item);
          print('Marked inspection $inspectionId as permanently deleted');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error permanently deleting inspection: $e');
      return false;
    }
  }

  /// Clear all trash items
  static Future<bool> clearTrash() async {
    try {
      await initialize();
      if (_trashBox == null) return false;

      await _trashBox!.clear();
      print('Trash cleared');
      return true;
    } catch (e) {
      print('Error clearing trash: $e');
      return false;
    }
  }

  /// Get trash box
  static Box<Map>? get trashBox => _trashBox;
}

/// Helper class for deleted items
class DeletedItem {
  final String id;
  final String inspectionId;
  final Map<String, dynamic> inspection;
  final DateTime deletedAt;
  final String? deletedBy;
  final String deletionReason;
  final bool isPermanent;

  DeletedItem({
    required this.id,
    required this.inspectionId,
    required this.inspection,
    required this.deletedAt,
    this.deletedBy,
    this.deletionReason = '',
    this.isPermanent = false,
  });

  factory DeletedItem.fromMap(Map<String, dynamic> map) {
    return DeletedItem(
      id: map['id'] as String,
      inspectionId: map['inspectionId'] as String,
      inspection: Map<String, dynamic>.from(map['inspection'] as Map),
      deletedAt: DateTime.parse(map['deletedAt'] as String),
      deletedBy: map['deletedBy'] as String?,
      deletionReason: map['deletionReason'] as String? ?? '',
      isPermanent: map['isPermanent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inspectionId': inspectionId,
      'inspection': inspection,
      'deletedAt': deletedAt.toIso8601String(),
      'deletedBy': deletedBy,
      'deletionReason': deletionReason,
      'isPermanent': isPermanent,
    };
  }
}

