import 'package:hive/hive.dart';

part 'inspection_history.g.dart';

@HiveType(typeId: 4)
class InspectionHistory extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String inspectionId; // Reference to inspection

  @HiveField(2)
  String action; // 'created', 'updated', 'status_changed', 'synced', etc.

  @HiveField(3)
  String? userId; // Inspector who made the change

  @HiveField(4)
  String? userName; // Inspector name

  @HiveField(5)
  DateTime timestamp;

  @HiveField(6)
  String? fieldName; // Which field was changed (e.g., 'mechanical_status', 'building_permit')

  @HiveField(7)
  String? oldValue; // Previous value

  @HiveField(8)
  String? newValue; // New value

  @HiveField(9)
  String? description; // Human-readable description

  @HiveField(10)
  Map<String, dynamic>? changes; // For tracking multiple field changes

  InspectionHistory({
    required this.id,
    required this.inspectionId,
    required this.action,
    required this.timestamp,
    this.userId,
    this.userName,
    this.fieldName,
    this.oldValue,
    this.newValue,
    this.description,
    this.changes,
  });

  factory InspectionHistory.create({
    required String inspectionId,
    required String action,
    String? userId,
    String? userName,
    String? fieldName,
    String? oldValue,
    String? newValue,
    String? description,
    Map<String, dynamic>? changes,
  }) {
    return InspectionHistory(
      id: 'history_${DateTime.now().millisecondsSinceEpoch}_${inspectionId}',
      inspectionId: inspectionId,
      action: action,
      timestamp: DateTime.now(),
      userId: userId,
      userName: userName,
      fieldName: fieldName,
      oldValue: oldValue,
      newValue: newValue,
      description: description,
      changes: changes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'action': action,
      'user_id': userId,
      'user_name': userName,
      'timestamp': timestamp.toIso8601String(),
      'field_name': fieldName,
      'old_value': oldValue,
      'new_value': newValue,
      'description': description,
      'changes': changes,
    };
  }
}

