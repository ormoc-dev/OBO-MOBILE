import 'package:hive/hive.dart';
import 'inspection.dart';

part 'deleted_inspection.g.dart';

@HiveType(typeId: 5)
class DeletedInspection extends HiveObject {
  @HiveField(0)
  Inspection inspection;

  @HiveField(1)
  DateTime deletedAt;

  @HiveField(2)
  String? deletedBy; // User ID or name

  @HiveField(3)
  String deletionReason; // Optional reason

  @HiveField(4)
  bool isPermanent; // If true, cannot be restored

  DeletedInspection({
    required this.inspection,
    required this.deletedAt,
    this.deletedBy,
    this.deletionReason = '',
    this.isPermanent = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'inspection': inspection.toJson(),
      'deletedAt': deletedAt.toIso8601String(),
      'deletedBy': deletedBy,
      'deletionReason': deletionReason,
      'isPermanent': isPermanent,
    };
  }

  factory DeletedInspection.fromJson(Map<String, dynamic> json) {
    return DeletedInspection(
      inspection: Inspection.fromJson(json['inspection']),
      deletedAt: DateTime.parse(json['deletedAt']),
      deletedBy: json['deletedBy'],
      deletionReason: json['deletionReason'] ?? '',
      isPermanent: json['isPermanent'] ?? false,
    );
  }
}


