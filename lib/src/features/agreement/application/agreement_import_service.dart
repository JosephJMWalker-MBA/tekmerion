import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../record/domain/evidence_envelope.dart';
import '../../../core/storage/evidence_storage.dart';
import '../domain/agreement.dart';
import '../domain/agreement_version.dart';
import '../domain/agreement_repository.dart';

abstract class FilePickerPort {
  Future<FileSelection?> pickPdfFile();
}

class FileSelection {
  const FileSelection({
    required this.bytes,
    required this.filename,
  });

  final Uint8List bytes;
  final String filename;
}

class ImportResult {
  const ImportResult({
    required this.agreement,
    required this.version,
    required this.evidence,
  });

  final Agreement agreement;
  final AgreementVersion version;
  final EvidenceEnvelope evidence;
}

class AgreementImportService {
  AgreementImportService({
    required this.filePicker,
    required this.evidenceStorage,
    required this.agreementRepository,
  });

  final FilePickerPort filePicker;
  final EvidenceStorage evidenceStorage;
  final AgreementRepository agreementRepository;

  Future<ImportResult?> importLease(
      {void Function(String state)? onStateChange}) async {
    // 1. Pick file
    onStateChange?.call('selecting');
    final selection = await filePicker.pickPdfFile();
    if (selection == null) {
      return null; // User canceled
    }

    if (selection.bytes.isEmpty) {
      throw Exception('Zero-byte file rejected');
    }

    if (!selection.filename.toLowerCase().endsWith('.pdf')) {
      throw Exception('Non-PDF file rejected');
    }

    // 2. Preserve and verify managed original
    onStateChange?.call('ingesting');
    final evidence = await evidenceStorage.ingestCapturedBytes(
      bytes: selection.bytes,
      originalFilename: selection.filename,
      mimeType: 'application/pdf',
    );

    final agreementId = const Uuid().v4();
    final versionId = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final agreement = Agreement(
      id: agreementId,
      title: selection.filename,
      agreementType: 'lease', // Default for Phase 1D
      status: AgreementStatus.setup,
      createdAt: now,
    );

    final version = AgreementVersion(
      id: versionId,
      agreementId: agreementId,
      sourceEvidenceAssetId: evidence.evidenceId,
      versionLabel: 'Original Import',
      status: AgreementVersionStatus.active,
      importedAt: now,
    );

    // 3. Begin database transaction (handled by repository)
    onStateChange?.call('savingAgreement');
    try {
      await agreementRepository.importAgreementTransaction(
        evidence: evidence,
        agreement: agreement,
        version: version,
      );
    } catch (e) {
      // 4. Cleanup on failure
      try {
        await evidenceStorage.deleteDraftAsset(evidence.storageIdentifier);
      } catch (_) {
        // Deferred recoverable cleanup
      }
      rethrow;
    }

    onStateChange?.call('completed');
    return ImportResult(
      agreement: agreement,
      version: version,
      evidence: evidence,
    );
  }
}
