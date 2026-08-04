import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../application/agreement_import_service.dart';

class FilePickerAdapter implements FilePickerPort {
  @override
  Future<FileSelection?> pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;

    Uint8List bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    } else {
      throw Exception('Could not read file bytes');
    }

    return FileSelection(
      bytes: bytes,
      filename: file.name,
    );
  }
}
