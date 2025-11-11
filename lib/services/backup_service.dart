import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'hive_offline_database.dart';
import 'helpers/local_file_saver_stub.dart'
    if (dart.library.io) 'helpers/local_file_saver_io.dart' as local_saver;
import 'helpers/web_file_saver_stub.dart'
    if (dart.library.html) 'helpers/web_file_saver_web.dart' as web_saver;

class BackupResult {
  final bool success;
  final String message;
  final String? filePath;

  const BackupResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}

class BackupService {
  static Future<BackupResult> exportInspectionsToExcel() async {
    final inspections = HiveOfflineDatabase.getInspections();

    if (inspections.isEmpty) {
      return const BackupResult(
        success: false,
        message: 'No inspections available to backup.',
      );
    }

    final excel = Excel.createExcel();
    final sheet = excel['Inspections'];

    // Header row
    sheet.appendRow([
      'Inspection ID',
      'Business ID',
      'Created At',
      'Updated At',
      'Synced',
      'Latitude',
      'Longitude',
      'Section Status',
      'Section Remarks',
      'Section Assessments',
      'Section Images',
      'Section Videos',
      'Start Time',
      'End Time',
    ]);

    for (final inspection in inspections) {
      sheet.appendRow([
        inspection.id,
        inspection.scannedData,
        inspection.createdAt.toIso8601String(),
        inspection.updatedAt.toIso8601String(),
        inspection.isSynced ? 'Yes' : 'No',
        inspection.latitude?.toString() ?? '',
        inspection.longitude?.toString() ?? '',
        _formatSectionStatus(inspection.sectionStatus),
        _formatSectionDetails({
          'Mechanical': inspection.mechanicalRemarks,
          'Line and Grade': inspection.lineGradeRemarks,
          'Architectural': inspection.architecturalRemarks,
          'Civil/Structural': inspection.civilStructuralRemarks,
          'Sanitary/Plumbing': inspection.sanitaryPlumbingRemarks,
          'Electrical/Electronics': inspection.electricalElectronicsRemarks,
        }),
        _formatSectionDetails({
          'Mechanical': inspection.mechanicalAssessment,
          'Line and Grade': inspection.lineGradeAssessment,
          'Architectural': inspection.architecturalAssessment,
          'Civil/Structural': inspection.civilStructuralAssessment,
          'Sanitary/Plumbing': inspection.sanitaryPlumbingAssessment,
          'Electrical/Electronics': inspection.electricalElectronicsAssessment,
        }),
        _formatMediaMap(inspection.sectionImagePaths),
        _formatMediaMap(inspection.sectionVideoPaths),
        inspection.inspectionStartTime?.toIso8601String() ?? '',
        inspection.inspectionEndTime?.toIso8601String() ?? '',
      ]);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      return const BackupResult(
        success: false,
        message: 'Failed to generate Excel workbook.',
      );
    }

    final Uint8List bytes = Uint8List.fromList(encoded);
    final fileName = 'obo_inspections_${_timestamp()}.xlsx';

    if (kIsWeb) {
      final saved = await web_saver.saveExcelOnWeb(bytes, fileName);
      return saved
          ? const BackupResult(
              success: true,
              message: 'Backup download started.',
            )
          : const BackupResult(
              success: false,
              message: 'Unable to trigger browser download.',
            );
    }

    final filePath = await local_saver.saveExcelLocally(bytes, fileName);

    if (filePath == null) {
      return const BackupResult(
        success: false,
        message: 'Unable to save backup file.',
      );
    }

    return BackupResult(
      success: true,
      message: 'Backup saved to $filePath',
      filePath: filePath,
    );
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  static String _formatSectionStatus(Map<String, String> status) {
    if (status.isEmpty) return '';
    return status.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
  }

  static String _formatSectionDetails(Map<String, String> details) {
    final buffer = StringBuffer();
    details.forEach((section, value) {
      if (value.isNotEmpty) {
        buffer.writeln('$section: $value');
      }
    });
    return buffer.toString().trim();
  }

  static String _formatMediaMap(Map<String, List<String>>? media) {
    if (media == null || media.isEmpty) return '';
    final buffer = StringBuffer();
    media.forEach((section, paths) {
      if (paths.isNotEmpty) {
        buffer.writeln('$section:');
        for (final path in paths) {
          buffer.writeln('  - $path');
        }
      }
    });
    return buffer.toString().trim();
  }
}

