import 'package:share_plus/share_plus.dart';

enum ExportShareResult {
  shared,
  cancelled,
  failed,
}

abstract class ExportShareAdapter {
  Future<ExportShareResult> sharePackage({
    required String filePath,
    required String filename,
    required String mimeType,
  });
}

class SharePlusExportAdapter implements ExportShareAdapter {
  @override
  Future<ExportShareResult> sharePackage({
    required String filePath,
    required String filename,
    required String mimeType,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, name: filename, mimeType: mimeType)],
          text: 'Tekmerion Record Package',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        return ExportShareResult.shared;
      } else if (result.status == ShareResultStatus.dismissed) {
        return ExportShareResult.cancelled;
      } else {
        return ExportShareResult.failed;
      }
    } catch (e) {
      return ExportShareResult.failed;
    }
  }
}
