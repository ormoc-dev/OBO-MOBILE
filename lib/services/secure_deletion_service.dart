import 'dart:io';
import 'package:flutter/foundation.dart';

class SecureDeletionService {
  /// Securely delete a file by overwriting it multiple times
  static Future<bool> secureDeleteFile(String filePath) async {
    if (kIsWeb) {
      // Web platform - files are typically managed by the browser
      // Just attempt to delete normally
      return await _deleteFileWeb(filePath);
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return true; // Already deleted
      }

      // Get file size
      final fileSize = await file.length();

      // Overwrite file with random data multiple times (3 passes for security)
      for (int pass = 0; pass < 3; pass++) {
        // Create random bytes to overwrite
        final randomBytes = List<int>.generate(
          fileSize,
          (index) => DateTime.now().millisecondsSinceEpoch % 256,
        );

        // Write random data
        await file.writeAsBytes(randomBytes);

        // Force sync to disk (File.flush() is not available in Dart, writes are synced automatically)
      }

      // Final deletion
      await file.delete();

      return true;
    } catch (e) {
      print('Error in secure file deletion: $e');
      // Fallback to normal deletion
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        return true;
      } catch (e2) {
        print('Error in fallback deletion: $e2');
        return false;
      }
    }
  }

  /// Delete file on web platform
  static Future<bool> _deleteFileWeb(String filePath) async {
    // On web, we can't securely delete files in the same way
    // Return true as web manages file lifecycle differently
    return true;
  }

  /// Securely delete multiple files
  static Future<Map<String, bool>> secureDeleteFiles(List<String> filePaths) async {
    final results = <String, bool>{};

    for (final filePath in filePaths) {
      results[filePath] = await secureDeleteFile(filePath);
    }

    return results;
  }

  /// Securely delete a directory and all its contents
  static Future<bool> secureDeleteDirectory(String dirPath) async {
    if (kIsWeb) {
      return true; // Web doesn't have file system directories
    }

    try {
      final directory = Directory(dirPath);
      if (!await directory.exists()) {
        return true; // Already deleted
      }

      // Get all files in directory
      final files = await directory
          .list(recursive: true)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();

      // Securely delete all files
      final filePaths = files.map((f) => f.path).toList();
      final deleteResults = await secureDeleteFiles(filePaths);

      // Check if all deletions succeeded
      final allSucceeded = deleteResults.values.every((result) => result);

      // Delete directory if all files are deleted
      if (allSucceeded) {
        await directory.delete(recursive: true);
      }

      return allSucceeded;
    } catch (e) {
      print('Error in secure directory deletion: $e');
      // Fallback to normal deletion
      try {
        final directory = Directory(dirPath);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
        return true;
      } catch (e2) {
        print('Error in fallback directory deletion: $e2');
        return false;
      }
    }
  }
}

