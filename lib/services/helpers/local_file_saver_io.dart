import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String?> saveExcelLocally(Uint8List bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);
  return filePath;
}

