import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

Future<bool> saveExcelOnWeb(Uint8List bytes, String fileName) async {
  try {
    final base64Data = base64Encode(bytes);
    final url =
        'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64Data';
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    return true;
  } catch (_) {
    return false;
  }
}

