// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inspection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InspectionAdapter extends TypeAdapter<Inspection> {
  @override
  final int typeId = 3;

  @override
  Inspection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Inspection(
      id: fields[0] as String,
      scannedData: fields[1] as String,
      mechanicalRemarks: fields[2] as String,
      mechanicalAssessment: fields[3] as String,
      lineGradeRemarks: fields[4] as String,
      lineGradeAssessment: fields[5] as String,
      architecturalRemarks: fields[6] as String,
      architecturalAssessment: fields[7] as String,
      civilStructuralRemarks: fields[8] as String,
      civilStructuralAssessment: fields[9] as String,
      sanitaryPlumbingRemarks: fields[10] as String,
      sanitaryPlumbingAssessment: fields[11] as String,
      electricalElectronicsRemarks: fields[12] as String,
      electricalElectronicsAssessment: fields[13] as String,
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime,
      isSynced: fields[16] as bool,
      userId: fields[17] as String?,
      latitude: fields[18] as double?,
      longitude: fields[19] as double?,
      imagePaths: (fields[20] as List).cast<String>(),
      videoPaths: (fields[21] as List).cast<String>(),
      inspectionStartTime: fields[22] as DateTime?,
      inspectionEndTime: fields[23] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Inspection obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.scannedData)
      ..writeByte(2)
      ..write(obj.mechanicalRemarks)
      ..writeByte(3)
      ..write(obj.mechanicalAssessment)
      ..writeByte(4)
      ..write(obj.lineGradeRemarks)
      ..writeByte(5)
      ..write(obj.lineGradeAssessment)
      ..writeByte(6)
      ..write(obj.architecturalRemarks)
      ..writeByte(7)
      ..write(obj.architecturalAssessment)
      ..writeByte(8)
      ..write(obj.civilStructuralRemarks)
      ..writeByte(9)
      ..write(obj.civilStructuralAssessment)
      ..writeByte(10)
      ..write(obj.sanitaryPlumbingRemarks)
      ..writeByte(11)
      ..write(obj.sanitaryPlumbingAssessment)
      ..writeByte(12)
      ..write(obj.electricalElectronicsRemarks)
      ..writeByte(13)
      ..write(obj.electricalElectronicsAssessment)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.updatedAt)
      ..writeByte(16)
      ..write(obj.isSynced)
      ..writeByte(17)
      ..write(obj.userId)
      ..writeByte(18)
      ..write(obj.latitude)
      ..writeByte(19)
      ..write(obj.longitude)
      ..writeByte(20)
      ..write(obj.imagePaths)
      ..writeByte(21)
      ..write(obj.videoPaths)
      ..writeByte(22)
      ..write(obj.inspectionStartTime)
      ..writeByte(23)
      ..write(obj.inspectionEndTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InspectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
