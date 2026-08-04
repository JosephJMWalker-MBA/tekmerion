import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/core/integrity/integrity_engine.dart';
import 'package:tekmerion/src/features/record/data/in_memory_record_repository.dart';
import 'package:tekmerion/src/features/record/domain/evidence_reference.dart';
import 'package:tekmerion/src/features/record/domain/record_entry.dart';

void main() {
  group('finalized record invariants', () {
    late InMemoryRecordRepository repository;

    setUp(() {
      repository = InMemoryRecordRepository(
        integrityEngine: const _FakeIntegrityEngine(),
        clock: () => DateTime.utc(2026, 8, 3, 20, 30),
      );
    });

    test('a valid draft finalizes with record and chain hashes', () async {
      final RecordEntry draft = _draft();
      await repository.saveDraft(draft);

      final RecordEntry finalized = await repository.finalize(draft.id);

      expect(finalized.state, RecordState.finalized);
      expect(finalized.finalizedAt, DateTime.utc(2026, 8, 3, 20, 30));
      expect(finalized.recordHash, isNotEmpty);
      expect(finalized.chainHash, isNotEmpty);
    });

    test('a finalized record cannot be silently updated', () async {
      final RecordEntry draft = _draft();
      await repository.saveDraft(draft);
      final RecordEntry finalized = await repository.finalize(draft.id);

      expect(
        () => repository.updateDraft(
          finalized.copyWith(factualDescription: 'Changed after finalization'),
        ),
        throwsA(isA<RecordMutationException>()),
      );
    });

    test('missing evidence bytes prevent finalization', () async {
      final RecordEntry draft = _draft(
        evidence: const <EvidenceReference>[
          EvidenceReference(
            evidenceId: 'evidence-1',
            sha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            captureMethod: EvidenceCaptureMethod.inAppCapture,
            assetRole: EvidenceAssetRole.original,
            bytesAvailable: false,
          ),
        ],
      );
      await repository.saveDraft(draft);

      expect(
        () => repository.finalize(draft.id),
        throwsA(isA<RecordMutationException>()),
      );
    });

    test('a correction must target a finalized record', () async {
      final RecordEntry originalDraft = _draft();
      await repository.saveDraft(originalDraft);

      final RecordEntry correction = _draft(
        id: 'record-correction',
        recordType: RecordType.correction,
        correctsRecordEntryId: originalDraft.id,
      );
      await repository.saveDraft(correction);

      expect(
        () => repository.finalize(correction.id),
        throwsA(isA<RecordMutationException>()),
      );
    });

    test('a finalized correction preserves the original', () async {
      final RecordEntry originalDraft = _draft();
      await repository.saveDraft(originalDraft);
      final RecordEntry original = await repository.finalize(originalDraft.id);

      final RecordEntry correctionDraft = _draft(
        id: 'record-correction',
        recordType: RecordType.correction,
        factualDescription: 'The payment was placed at 9:16 AM, not 9:14 AM.',
        correctsRecordEntryId: original.id,
        recordedAt: DateTime.utc(2026, 8, 3, 20, 31),
      );
      await repository.saveDraft(correctionDraft);
      final RecordEntry correction =
          await repository.finalize(correctionDraft.id);

      final fetchedOriginal = await repository.getById(original.id);
      expect(fetchedOriginal?.factualDescription, original.factualDescription);
      expect(correction.correctsRecordEntryId, original.id);
      expect(correction.previousChainHash, original.chainHash);
    });
  });
}

RecordEntry _draft({
  String id = 'record-1',
  RecordType recordType = RecordType.performance,
  String factualDescription = 'August rent was placed in the office drop box.',
  String? correctsRecordEntryId,
  DateTime? recordedAt,
  List<EvidenceReference> evidence = const <EvidenceReference>[
    EvidenceReference(
      evidenceId: 'evidence-1',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      captureMethod: EvidenceCaptureMethod.inAppCapture,
      assetRole: EvidenceAssetRole.original,
      bytesAvailable: true,
    ),
  ],
}) {
  return RecordEntry(
    id: id,
    workspaceId: 'workspace-1',
    agreementId: 'agreement-1',
    agreementVersionId: 'agreement-version-1',
    obligationId: 'obligation-1',
    sourceClauseId: 'clause-1',
    recordType: recordType,
    title: 'Document rent payment',
    factualDescription: factualDescription,
    occurredAt: DateTime.utc(2026, 8, 3, 13, 14),
    recordedAt: recordedAt ?? DateTime.utc(2026, 8, 3, 13, 15),
    timezone: 'America/New_York',
    createdByPartyId: 'party-tenant',
    correctsRecordEntryId: correctsRecordEntryId,
    state: RecordState.draft,
    evidence: evidence,
  );
}

class _FakeIntegrityEngine implements IntegrityEngine {
  const _FakeIntegrityEngine();

  @override
  String hashChain({
    required String? previousChainHash,
    required String recordHash,
  }) {
    return 'chain:${previousChainHash ?? 'genesis'}:$recordHash';
  }

  @override
  String hashRecord(List<int> canonicalBytes) {
    return 'record:${canonicalBytes.length}:${canonicalBytes.fold<int>(0, (int sum, int byte) => sum + byte)}';
  }
}
