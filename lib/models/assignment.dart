import 'package:json_annotation/json_annotation.dart';
import 'package:hive/hive.dart';

part 'assignment.g.dart';

@HiveType(typeId: 1)
@JsonSerializable()
class Assignment {
  @HiveField(0)
  @JsonKey(name: 'assignment_id')
  final int assignmentId;
  @HiveField(1)
  final String status;
  @HiveField(2)
  @JsonKey(name: 'inspection_date')
  final String? inspectionDate;
  @HiveField(3)
  @JsonKey(name: 'completion_date')
  final String? completionDate;
  @HiveField(4)
  @JsonKey(name: 'assigned_at')
  final String assignedAt;
  @HiveField(5)
  @JsonKey(name: 'assignment_notes')
  final String? assignmentNotes;
  @HiveField(6)
  @JsonKey(name: 'business_assignment_id')
  final int businessAssignmentId;
  @HiveField(7)
  @JsonKey(name: 'business_id')
  final String businessId;
  @HiveField(8)
  @JsonKey(name: 'business_name')
  final String businessName;
  @HiveField(9)
  @JsonKey(name: 'business_address')
  final String? businessAddress;
  @HiveField(10)
  @JsonKey(name: 'business_notes')
  final String? businessNotes;
  @HiveField(11)
  @JsonKey(name: 'department_name')
  final String departmentName;
  @HiveField(12)
  @JsonKey(name: 'department_description')
  final String? departmentDescription;
  @HiveField(13)
  @JsonKey(name: 'assigned_by_name')
  final String? assignedByName;
  @HiveField(14)
  @JsonKey(name: 'assigned_by_admin')
  final String? assignedByAdmin;

  Assignment({
    required this.assignmentId,
    required this.status,
    this.inspectionDate,
    this.completionDate,
    required this.assignedAt,
    this.assignmentNotes,
    required this.businessAssignmentId,
    required this.businessId,
    required this.businessName,
    this.businessAddress,
    this.businessNotes,
    required this.departmentName,
    this.departmentDescription,
    this.assignedByName,
    this.assignedByAdmin,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) => _$AssignmentFromJson(json);
  Map<String, dynamic> toJson() => _$AssignmentToJson(this);

  // Helper methods
  String get statusDisplayName {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get statusColor {
    switch (status) {
      case 'assigned':
        return '#FFA500'; // Orange
      case 'in_progress':
        return '#007BFF'; // Blue
      case 'completed':
        return '#28A745'; // Green
      case 'cancelled':
        return '#DC3545'; // Red
      default:
        return '#6C757D'; // Gray
    }
  }

  bool get isPending => status == 'assigned';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}

@HiveType(typeId: 2)
@JsonSerializable()
class AssignmentStatistics {
  @HiveField(0)
  @JsonKey(name: 'total_assignments', fromJson: _stringToInt)
  final int totalAssignments;
  @HiveField(1)
  @JsonKey(name: 'pending_assignments', fromJson: _stringToInt)
  final int pendingAssignments;
  @HiveField(2)
  @JsonKey(name: 'in_progress_assignments', fromJson: _stringToInt)
  final int inProgressAssignments;
  @HiveField(3)
  @JsonKey(name: 'completed_assignments', fromJson: _stringToInt)
  final int completedAssignments;
  @HiveField(4)
  @JsonKey(name: 'cancelled_assignments', fromJson: _stringToInt)
  final int cancelledAssignments;

  AssignmentStatistics({
    required this.totalAssignments,
    required this.pendingAssignments,
    required this.inProgressAssignments,
    required this.completedAssignments,
    required this.cancelledAssignments,
  });

  factory AssignmentStatistics.fromJson(Map<String, dynamic> json) => _$AssignmentStatisticsFromJson(json);
  Map<String, dynamic> toJson() => _$AssignmentStatisticsToJson(this);
}

// Helper function to convert string to int
int _stringToInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

@JsonSerializable()
class AssignmentResponse {
  final bool success;
  final String message;
  final AssignmentData? data;

  AssignmentResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory AssignmentResponse.fromJson(Map<String, dynamic> json) => _$AssignmentResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AssignmentResponseToJson(this);
}

@JsonSerializable()
class AssignmentData {
  final List<Assignment> assignments;
  final AssignmentStatistics statistics;
  final AssignmentPagination pagination;

  AssignmentData({
    required this.assignments,
    required this.statistics,
    required this.pagination,
  });

  factory AssignmentData.fromJson(Map<String, dynamic> json) => _$AssignmentDataFromJson(json);
  Map<String, dynamic> toJson() => _$AssignmentDataToJson(this);
}

@JsonSerializable()
class AssignmentPagination {
  final int limit;
  final int offset;
  final int total;

  AssignmentPagination({
    required this.limit,
    required this.offset,
    required this.total,
  });

  factory AssignmentPagination.fromJson(Map<String, dynamic> json) => _$AssignmentPaginationFromJson(json);
  Map<String, dynamic> toJson() => _$AssignmentPaginationToJson(this);
}
