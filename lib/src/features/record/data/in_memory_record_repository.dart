import '../domain/record_canonicalizer.dart';
import '../domain/record_entry.dart';
import '../domain/record_integrity_engine.dart';

class RecordMutationException implements Exception {
  const RecordMutationException(this.message);

  final String message;

  @override
  String toString() => 'RecordMutationException: $message';
}

class InMemoryRecordRepository {
  InMemoryRecordRepository({
    required RecordIntegrityEngine integrityEngine,
    RecordCanonicalizer canonicalizer = const RecordCanonicalizer(),
    DateTime Function()? clock,
  })  : _integrityEngine = integrityEngine,
        _canonicalizer = canonicalizer,
        _clock = clock ?? DateTime.now;

  final RecordIntegrityEngine _integrityEngine;
  final RecordCanonicalizer _canonicalizer;
  final DateTime Function() _clock;
  final Map<String, RecordEntry> _records = <String, RecordEntry>{};
  final Map<String, String> _latestAgreementChainHash = <String, String>{};

  RecordEntry? getById(String id) => _records[id];

  List<RecordEntry> allForAgreement(String agreementId) {
    final List<RecordEntry> records = _records.values
        .where((RecordEntry record) => record.agreementId == agreementId)
        .toList()
      ..sort(
        (RecordEntry left, RecordEntry right) =>
            left.recordedAt.compareTo(right.recordedAt),
      );
    return List<RecordEntry>.unmodifiable(records);
  }

  void saveDraft(RecordEntry draft) {
    if (draft.state != RecordState.draft || draft.finalizedAt != null) {
      throw const RecordMutationException('Only mutable drafts may be saved.');
    }
    if (_records.containsKey(draft.id)) {
      throw const RecordMutationException('Record ID already exists.');
    }
    _records[draft.id] = draft;
  }

  void updateDraft(RecordEntry updatedDraft) {
    final RecordEntry current = _requireRecord(updatedDraft.id);
    if (current.isFinalized) {
      throw const RecordMutationException(
        'A finalized record cannot be edited in place.',
      );
    }
    if (updatedDraft.state != RecordState.draft ||
        updatedDraft.finalizedAt != null) {
      throw const RecordMutationException('Draft update has invalid state.');
    }
    _records[updatedDraft.id] = updatedDraft;
  }

  RecordEntry finalize(String id) {
    final RecordEntry draft = _requireRecord(id);
    if (draft.isFinalized) {
      throw const RecordMutationException('Record is already finalized.');
    }
    _validateFinalization(draft);

    final DateTime finalizedAt = _clock().toUtc();
    final List<int> canonicalBytes =
        _canonicalizer.canonicalBytes(draft, finalizedAt);
    final String recordHash = _integrityEngine.hashRecord(canonicalBytes);
    final String? previousChainHash =
        _latestAgreementChainHash[draft.agreementId];
    final String chainHash = _integrityEngine.hashChain(
      previousChainHash: previousChainHash,
      recordHash: recordHash,
    );

    final RecordEntry finalized = draft.copyWith(
      finalizedAt: finalizedAt,
      recordHash: recordHash,
      previousChainHash: previousChainHash,
      chainHash: chainHash,
      state: RecordState.finalized,
    );

    _records[id] = finalized;
    _latestAgreementChainHash[draft.agreementId] = chainHash;
    return finalized;
  }

  void _validateFinalization(RecordEntry draft) {
    if (draft.id.trim().isEmpty ||
        draft.workspaceId.trim().isEmpty ||
        draft.agreementId.trim().isEmpty ||
        draft.agreementVersionId.trim().isEmpty ||
        draft.title.trim().isEmpty ||
        draft.factualDescription.trim().isEmpty ||
        draft.timezone.trim().isEmpty ||
        draft.createdByPartyId.trim().isEmpty) {
      throw const RecordMutationException(
        'Required finalized-record fields are missing.',
      );
    }

    for (final evidence in draft.evidence) {
      if (!evidence.bytesAvailable) {
        throw const RecordMutationException(
          'Evidence bytes must exist before finalization.',
        );
      }
      if (!evidence.hasValidSha256) {
        throw const RecordMutationException(
          'Evidence must have a valid SHA-256 digest.',
        );
      }
    }

    if (draft.recordType == RecordType.correction &&
        draft.correctsRecordEntryId == null) {
      throw const RecordMutationException(
        'A correction must reference a finalized record.',
      );
    }

    if (draft.correctsRecordEntryId != null) {
      final RecordEntry target = _requireRecord(draft.correctsRecordEntryId!);
      if (!target.isFinalized) {
        throw const RecordMutationException(
          'A correction cannot target a draft.',
        );
      }
    }
  }

  RecordEntry _requireRecord(String id) {
    final RecordEntry? record = _records[id];
    if (record == null) {
      throw RecordMutationException('Record not found: $id');
    }
    return record;
  }
}
