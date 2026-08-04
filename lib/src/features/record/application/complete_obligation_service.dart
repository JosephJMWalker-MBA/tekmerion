import 'package:uuid/uuid.dart';

import '../../../core/storage/evidence_storage.dart';
import '../../agreement/application/agreement_import_service.dart';
import '../../obligation/domain/obligation_repository.dart';
import '../../record/domain/evidence_reference.dart';
import '../../record/domain/record_entry.dart';
import '../../record/domain/record_repository.dart';

class CompleteObligationResult {
  const CompleteObligationResult({
    required this.recordEntry,
  });
  final RecordEntry recordEntry;
}

class CompleteObligationService {
  CompleteObligationService({
    required this.filePicker,
    required this.evidenceStorage,
    required this.recordRepository,
    required this.obligationRepository,
  });

  final FilePickerPort filePicker;
  final EvidenceStorage evidenceStorage;
  final RecordRepository recordRepository;
  final ObligationRepository obligationRepository;

  /// Completes an obligation by creating a finalized performance record.
  /// If [pickEvidence] is true, prompts the user to select a file.
  Future<CompleteObligationResult?> completeObligation({
    required String obligationId,
    required String agreementVersionId,
    required String note,
    required DateTime occurredAt,
    required bool pickEvidence,
    void Function(String state)? onStateChange,
  }) async {
    final obligation =
        await obligationRepository.getObligationById(obligationId);
    if (obligation == null) {
      throw StateError('Obligation not found.');
    }

    final evidenceList = <EvidenceReference>[];

    if (pickEvidence) {
      onStateChange?.call('selecting_evidence');
      // For now we reuse pickPdfFile, though we might want to pick images too.
      // Assuming pickPdfFile returns a FileSelection.
      final selection = await filePicker.pickPdfFile();
      if (selection != null && selection.bytes.isNotEmpty) {
        onStateChange?.call('ingesting_evidence');

        // Ingest into evidence storage
        final evidenceEnvelope = await evidenceStorage.ingestCapturedBytes(
          bytes: selection.bytes,
          originalFilename: selection.filename,
          mimeType: selection.filename.toLowerCase().endsWith('.pdf')
              ? 'application/pdf'
              : 'application/octet-stream', // Generic fallback
        );

        evidenceList.add(
          EvidenceReference(
            evidenceId: evidenceEnvelope.evidenceId,
            sha256: evidenceEnvelope.sha256,
            captureMethod: EvidenceCaptureMethod.externalImport,
            assetRole: EvidenceAssetRole.original,
            bytesAvailable: true,
          ),
        );
      }
    }

    onStateChange?.call('saving_record');
    final recordId = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final draftRecord = RecordEntry(
      id: recordId,
      workspaceId: 'default-workspace', // Fallback for phase 1
      agreementId: obligation.agreementId,
      agreementVersionId: agreementVersionId,
      obligationId: obligation.id,
      sourceClauseId: obligation.sourceClauseId,
      recordType: RecordType.performance,
      title: 'Completed: ${obligation.title}',
      factualDescription: note,
      occurredAt: occurredAt.toUtc(),
      recordedAt: now,
      timezone: 'UTC',
      createdByPartyId: 'self', // Default
      state: RecordState.draft,
      evidence: evidenceList,
    );

    // Save the draft record
    await recordRepository.saveDraft(draftRecord);

    // Finalize the record
    final finalizedRecord = await recordRepository.finalize(draftRecord.id);

    onStateChange?.call('updating_obligation');
    await obligationRepository.markObligationFulfilled(obligation.id);

    onStateChange?.call('completed');
    return CompleteObligationResult(recordEntry: finalizedRecord);
  }
}
