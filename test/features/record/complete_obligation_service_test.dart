import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/core/storage/evidence_storage.dart';
import 'package:tekmerion/src/features/agreement/application/agreement_import_service.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation_repository.dart';
import 'package:tekmerion/src/features/record/application/complete_obligation_service.dart';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';
import 'package:tekmerion/src/features/record/domain/evidence_reference.dart';
import 'package:tekmerion/src/features/record/domain/record_entry.dart';
import 'package:tekmerion/src/features/record/domain/record_repository.dart';

class MockFilePicker implements FilePickerPort {
  bool willReturnNull = false;
  @override
  Future<FileSelection?> pickPdfFile() async {
    if (willReturnNull) return null;
    return FileSelection(
      filename: 'receipt.pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
  }
}

class MockEvidenceStorage implements EvidenceStorage {
  @override
  Future<EvidenceEnvelope> ingestCapturedBytes({
    required Uint8List bytes,
    required String originalFilename,
    required String mimeType,
    String? derivedFromEvidenceId,
  }) async {
    return EvidenceEnvelope(
      evidenceId: 'e1',
      sha256: 'somehash',
      originalFilename: originalFilename,
      mimeType: mimeType,
      byteSize: bytes.length,
      ingestedAt: DateTime.now(),
      captureMethod: EvidenceCaptureMethod.externalImport,
      storageIdentifier: 'file1.pdf',
      assetRole: EvidenceAssetRole.original,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockRecordRepository implements RecordRepository {
  RecordEntry? savedDraft;
  RecordEntry? finalizedRecord;

  @override
  Future<void> saveDraft(RecordEntry draft) async {
    savedDraft = draft;
  }

  @override
  Future<RecordEntry> finalize(String recordId) async {
    if (savedDraft == null || savedDraft!.id != recordId) {
      throw StateError('Draft not found');
    }
    finalizedRecord = savedDraft!.copyWith(
      state: RecordState.finalized,
      recordHash: 'recordhash',
      chainHash: 'chainhash',
    );
    return finalizedRecord!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockObligationRepository implements ObligationRepository {
  bool fulfilledCalled = false;
  final Obligation testObligation = Obligation(
    id: 'o1',
    agreementId: 'a1',
    sourceClauseId: 'c1',
    sourceType: ObligationSourceType.contractual,
    title: 'Test',
    description: 'Desc',
    obligationCategory: 'payment',
    status: ObligationStatus.confirmed,
    createdAt: DateTime.now(),
  );

  @override
  Future<Obligation?> getObligationById(String obligationId) async {
    if (obligationId == 'o1') return testObligation;
    return null;
  }

  @override
  Future<void> markObligationFulfilled(String obligationId) async {
    if (obligationId == 'o1') fulfilledCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('completeObligation saves record and updates obligation', () async {
    final filePicker = MockFilePicker();
    final storage = MockEvidenceStorage();
    final recordRepo = MockRecordRepository();
    final obligationRepo = MockObligationRepository();

    final service = CompleteObligationService(
      filePicker: filePicker,
      evidenceStorage: storage,
      recordRepository: recordRepo,
      obligationRepository: obligationRepo,
    );

    final states = <String>[];

    final result = await service.completeObligation(
      obligationId: 'o1',
      agreementVersionId: 'v1',
      note: 'Paid in full',
      occurredAt: DateTime(2025, 1, 1),
      pickEvidence: true,
      onStateChange: (state) => states.add(state),
    );

    expect(result, isNotNull);
    expect(result!.recordEntry.state, RecordState.finalized);
    expect(result.recordEntry.factualDescription, 'Paid in full');
    expect(result.recordEntry.evidence, hasLength(1));
    expect(result.recordEntry.evidence.first.evidenceId, 'e1');

    expect(recordRepo.savedDraft, isNotNull);
    expect(recordRepo.finalizedRecord, isNotNull);
    expect(obligationRepo.fulfilledCalled, isTrue);

    expect(states, [
      'selecting_evidence',
      'ingesting_evidence',
      'saving_record',
      'updating_obligation',
      'completed',
    ]);
  });
}
