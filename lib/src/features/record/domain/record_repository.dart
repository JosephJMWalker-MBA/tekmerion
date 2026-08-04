import 'package:tekmerion/src/features/record/domain/record_entry.dart';

abstract interface class RecordRepository {
  /// Retrieves a draft or finalized record by its unique ID.
  Future<RecordEntry?> getById(String id);

  /// Saves a new draft record. The record must have its state set to draft.
  Future<void> saveDraft(RecordEntry draft);

  /// Updates an existing draft record. Throws if the record is finalized.
  Future<void> updateDraft(RecordEntry updatedDraft);

  /// Finalizes a draft record, creating a permanent, immutable entry in the
  /// timeline. It computes the record hash, chains it to the previous hash,
  /// and updates the record's state to finalized.
  Future<RecordEntry> finalize(String id);

  /// Verifies if a specific evidence asset ID is present and managed by the system.
  Future<bool> hasEvidence(String evidenceId);

  /// Retrieves the latest chain hash for a specific agreement to append the next record.
  Future<String?> getLatestChainHashForAgreement(String agreementId);

  /// Retrieves all records (draft and finalized) for an agreement.
  Future<List<RecordEntry>> allForAgreement(String agreementId);
}
