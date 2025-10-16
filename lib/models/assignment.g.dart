// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assignment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AssignmentAdapter extends TypeAdapter<Assignment> {
  @override
  final int typeId = 1;

  @override
  Assignment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Assignment(
      assignmentId: fields[0] as int,
      status: fields[1] as String,
      inspectionDate: fields[2] as String?,
      completionDate: fields[3] as String?,
      assignedAt: fields[4] as String,
      assignmentNotes: fields[5] as String?,
      businessAssignmentId: fields[6] as int,
      businessId: fields[7] as String,
      businessName: fields[8] as String,
      businessAddress: fields[9] as String?,
      businessNotes: fields[10] as String?,
      departmentName: fields[11] as String,
      departmentDescription: fields[12] as String?,
      assignedByName: fields[13] as String?,
      assignedByAdmin: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Assignment obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.assignmentId)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.inspectionDate)
      ..writeByte(3)
      ..write(obj.completionDate)
      ..writeByte(4)
      ..write(obj.assignedAt)
      ..writeByte(5)
      ..write(obj.assignmentNotes)
      ..writeByte(6)
      ..write(obj.businessAssignmentId)
      ..writeByte(7)
      ..write(obj.businessId)
      ..writeByte(8)
      ..write(obj.businessName)
      ..writeByte(9)
      ..write(obj.businessAddress)
      ..writeByte(10)
      ..write(obj.businessNotes)
      ..writeByte(11)
      ..write(obj.departmentName)
      ..writeByte(12)
      ..write(obj.departmentDescription)
      ..writeByte(13)
      ..write(obj.assignedByName)
      ..writeByte(14)
      ..write(obj.assignedByAdmin);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AssignmentStatisticsAdapter extends TypeAdapter<AssignmentStatistics> {
  @override
  final int typeId = 2;

  @override
  AssignmentStatistics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AssignmentStatistics(
      totalAssignments: fields[0] as int,
      pendingAssignments: fields[1] as int,
      inProgressAssignments: fields[2] as int,
      completedAssignments: fields[3] as int,
      cancelledAssignments: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AssignmentStatistics obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.totalAssignments)
      ..writeByte(1)
      ..write(obj.pendingAssignments)
      ..writeByte(2)
      ..write(obj.inProgressAssignments)
      ..writeByte(3)
      ..write(obj.completedAssignments)
      ..writeByte(4)
      ..write(obj.cancelledAssignments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignmentStatisticsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Assignment _$AssignmentFromJson(Map<String, dynamic> json) => Assignment(
      assignmentId: (json['assignment_id'] as num).toInt(),
      status: json['status'] as String,
      inspectionDate: json['inspection_date'] as String?,
      completionDate: json['completion_date'] as String?,
      assignedAt: json['assigned_at'] as String,
      assignmentNotes: json['assignment_notes'] as String?,
      businessAssignmentId: (json['business_assignment_id'] as num).toInt(),
      businessId: json['business_id'] as String,
      businessName: json['business_name'] as String,
      businessAddress: json['business_address'] as String?,
      businessNotes: json['business_notes'] as String?,
      departmentName: json['department_name'] as String,
      departmentDescription: json['department_description'] as String?,
      assignedByName: json['assigned_by_name'] as String?,
      assignedByAdmin: json['assigned_by_admin'] as String?,
    );

Map<String, dynamic> _$AssignmentToJson(Assignment instance) =>
    <String, dynamic>{
      'assignment_id': instance.assignmentId,
      'status': instance.status,
      'inspection_date': instance.inspectionDate,
      'completion_date': instance.completionDate,
      'assigned_at': instance.assignedAt,
      'assignment_notes': instance.assignmentNotes,
      'business_assignment_id': instance.businessAssignmentId,
      'business_id': instance.businessId,
      'business_name': instance.businessName,
      'business_address': instance.businessAddress,
      'business_notes': instance.businessNotes,
      'department_name': instance.departmentName,
      'department_description': instance.departmentDescription,
      'assigned_by_name': instance.assignedByName,
      'assigned_by_admin': instance.assignedByAdmin,
    };

AssignmentStatistics _$AssignmentStatisticsFromJson(
        Map<String, dynamic> json) =>
    AssignmentStatistics(
      totalAssignments: _stringToInt(json['total_assignments']),
      pendingAssignments: _stringToInt(json['pending_assignments']),
      inProgressAssignments: _stringToInt(json['in_progress_assignments']),
      completedAssignments: _stringToInt(json['completed_assignments']),
      cancelledAssignments: _stringToInt(json['cancelled_assignments']),
    );

Map<String, dynamic> _$AssignmentStatisticsToJson(
        AssignmentStatistics instance) =>
    <String, dynamic>{
      'total_assignments': instance.totalAssignments,
      'pending_assignments': instance.pendingAssignments,
      'in_progress_assignments': instance.inProgressAssignments,
      'completed_assignments': instance.completedAssignments,
      'cancelled_assignments': instance.cancelledAssignments,
    };

AssignmentResponse _$AssignmentResponseFromJson(Map<String, dynamic> json) =>
    AssignmentResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : AssignmentData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AssignmentResponseToJson(AssignmentResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };

AssignmentData _$AssignmentDataFromJson(Map<String, dynamic> json) =>
    AssignmentData(
      assignments: (json['assignments'] as List<dynamic>)
          .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
          .toList(),
      statistics: AssignmentStatistics.fromJson(
          json['statistics'] as Map<String, dynamic>),
      pagination: AssignmentPagination.fromJson(
          json['pagination'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AssignmentDataToJson(AssignmentData instance) =>
    <String, dynamic>{
      'assignments': instance.assignments,
      'statistics': instance.statistics,
      'pagination': instance.pagination,
    };

AssignmentPagination _$AssignmentPaginationFromJson(
        Map<String, dynamic> json) =>
    AssignmentPagination(
      limit: (json['limit'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$AssignmentPaginationToJson(
        AssignmentPagination instance) =>
    <String, dynamic>{
      'limit': instance.limit,
      'offset': instance.offset,
      'total': instance.total,
    };
