import 'package:sqflite/sqflite.dart';
import 'package:tekmerion/src/core/database/app_database.dart';
import 'package:tekmerion/src/core/integrity/integrity_engine.dart';
import 'package:tekmerion/src/core/storage/evidence_storage.dart';
import 'package:tekmerion/src/features/record/domain/evidence_reference.dart';
import 'package:tekmerion/src/features/record/domain/record_canonicalizer.dart';
import 'package:tekmerion/src/features/record/domain/record_entry.dart';
import 'package:tekmerion/src/features/record/domain/record_repository.dart';

class SqliteRecordRepository implements RecordRepository {
  SqliteRecordRepository({
    required this.integrityEngine,
    required this.evidenceStorage,
    RecordCanonicalizer canonicalizer = const RecordCanonicalizer(),
    DateTime Function()? clock,
  })  : _canonicalizer = canonicalizer,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final IntegrityEngine integrityEngine;
  final EvidenceStorage evidenceStorage;
  final RecordCanonicalizer _canonicalizer;
  final DateTime Function() _clock;

  Database get _db => AppDatabase.instance;

  @override
  Future<RecordEntry?> getById(String id) async {
    final records =
        await _db.query('record_entries', where: 'id = ?', whereArgs: [id]);
    if (records.isEmpty) {
      return null;
    }

    final row = records.first;

    // Fetch evidence
    final evidenceRows = await _db.rawQuery(
      '''
      SELECT e.id, e.sha256, e.capture_method, e.asset_role, e.deletion_state
      FROM record_evidence_links l
      JOIN evidence_assets e ON l.evidence_asset_id = e.id
      WHERE l.record_entry_id = ?
      ORDER BY l.display_order ASC
    ''',
      [id],
    );

    final evidence = evidenceRows
        .map(
          (eRow) => EvidenceReference(
            evidenceId: eRow['id'] as String,
            sha256: eRow['sha256'] as String,
            captureMethod: EvidenceCaptureMethod.values
                .firstWhere((r) => r.name == eRow['capture_method']),
            assetRole: EvidenceAssetRole.values
                .firstWhere((r) => r.name == eRow['asset_role']),
            bytesAvailable: eRow['deletion_state'] != 'deleted',
          ),
        )
        .toList();

    return RecordEntry(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      agreementId: row['agreement_id'] as String,
      agreementVersionId: row['agreement_version_id'] as String,
      obligationId: row['obligation_id'] as String?,
      sourceClauseId: row['source_clause_id'] as String?,
      recordType:
          RecordType.values.firstWhere((t) => t.name == row['record_type']),
      title: row['title'] as String,
      factualDescription: row['factual_description'] as String,
      interpretationText: row['interpretation_text'] as String?,
      occurredAt: DateTime.parse(row['occurred_at'] as String),
      recordedAt: DateTime.parse(row['recorded_at'] as String),
      timezone: row['timezone'] as String,
      createdByPartyId: row['created_by_party_id'] as String,
      correctsRecordEntryId: row['corrects_record_entry_id'] as String?,
      state: RecordState.values.firstWhere((s) => s.name == row['state']),
      finalizedAt: row['finalized_at'] != null
          ? DateTime.parse(row['finalized_at'] as String)
          : null,
      recordHash: row['record_hash'] as String?,
      previousChainHash: row['previous_chain_hash'] as String?,
      chainHash: row['chain_hash'] as String?,
      evidence: evidence,
    );
  }

  @override
  Future<void> saveDraft(RecordEntry draft) async {
    if (draft.state != RecordState.draft) {
      throw ArgumentError('Only drafts can be saved via saveDraft');
    }
    await _insertOrUpdateDraft(draft);
  }

  @override
  Future<void> updateDraft(RecordEntry updatedDraft) async {
    if (updatedDraft.state != RecordState.draft) {
      throw StateError('Cannot update a record that is already finalized.');
    }

    final existing = await getById(updatedDraft.id);
    if (existing != null && existing.isFinalized) {
      throw StateError('Cannot update a finalized record.');
    }

    await _insertOrUpdateDraft(updatedDraft);
  }

  Future<void> _insertOrUpdateDraft(RecordEntry record) async {
    await _db.transaction((txn) async {
      final entryValues = {
        'id': record.id,
        'workspace_id': record.workspaceId,
        'agreement_id': record.agreementId,
        'agreement_version_id': record.agreementVersionId,
        'obligation_id': record.obligationId,
        'source_clause_id': record.sourceClauseId,
        'record_type': record.recordType.name,
        'title': record.title,
        'factual_description': record.factualDescription,
        'interpretation_text': record.interpretationText,
        'occurred_at': record.occurredAt.toIso8601String(),
        'recorded_at': record.recordedAt.toIso8601String(),
        'timezone': record.timezone,
        'created_by_party_id': record.createdByPartyId,
        'corrects_record_entry_id': record.correctsRecordEntryId,
        'state': record.state.name,
        'canonicalization_version': '1', // Hardcoded for now
        'signature_state': 'unsigned', // Default
        'finalized_at': record.finalizedAt?.toIso8601String(),
        'record_hash': record.recordHash,
        'previous_chain_hash': record.previousChainHash,
        'chain_hash': record.chainHash,
      };

      await txn.insert(
        'record_entries',
        entryValues,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Handle evidence links (replace all)
      await txn.delete(
        'record_evidence_links',
        where: 'record_entry_id = ?',
        whereArgs: [record.id],
      );

      for (var i = 0; i < record.evidence.length; i++) {
        final ev = record.evidence[i];

        await txn.insert('record_evidence_links', {
          'id': '${record.id}_${ev.evidenceId}',
          'record_entry_id': record.id,
          'evidence_asset_id': ev.evidenceId,
          'relationship_type': 'primary',
          'display_order': i,
        });
      }
    });
  }

  @override
  Future<RecordEntry> finalize(String id) async {
    return _db.transaction((txn) async {
      // 1. Fetch current draft inside transaction
      final records =
          await txn.query('record_entries', where: 'id = ?', whereArgs: [id]);
      if (records.isEmpty) {
        throw StateError('Record not found.');
      }
      final row = records.first;
      if (row['state'] == RecordState.finalized.name) {
        throw StateError('Record is already finalized.');
      }

      // Reconstruct domain object (ignoring evidence for a moment)
      // Actually we need evidence to verify
      final evidenceRows = await txn.rawQuery(
        '''
        SELECT e.id, e.sha256, e.byte_size, e.managed_storage_identifier, e.capture_method, e.asset_role, e.deletion_state
        FROM record_evidence_links l
        JOIN evidence_assets e ON l.evidence_asset_id = e.id
        WHERE l.record_entry_id = ?
        ORDER BY l.display_order ASC
      ''',
        [id],
      );

      final evidence = evidenceRows
          .map(
            (eRow) => EvidenceReference(
              evidenceId: eRow['id'] as String,
              sha256: eRow['sha256'] as String,
              captureMethod: EvidenceCaptureMethod.values
                  .firstWhere((r) => r.name == eRow['capture_method']),
              assetRole: EvidenceAssetRole.values
                  .firstWhere((r) => r.name == eRow['asset_role']),
              bytesAvailable: eRow['deletion_state'] != 'deleted',
            ),
          )
          .toList();

      final draft = RecordEntry(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        agreementId: row['agreement_id'] as String,
        agreementVersionId: row['agreement_version_id'] as String,
        obligationId: row['obligation_id'] as String?,
        sourceClauseId: row['source_clause_id'] as String?,
        recordType:
            RecordType.values.firstWhere((t) => t.name == row['record_type']),
        title: row['title'] as String,
        factualDescription: row['factual_description'] as String,
        interpretationText: row['interpretation_text'] as String?,
        occurredAt: DateTime.parse(row['occurred_at'] as String),
        recordedAt: DateTime.parse(row['recorded_at'] as String),
        timezone: row['timezone'] as String,
        createdByPartyId: row['created_by_party_id'] as String,
        correctsRecordEntryId: row['corrects_record_entry_id'] as String?,
        state: RecordState.draft,
        evidence: evidence,
      );

      // 2. Verify all evidence (Rollback on failure)
      for (final eRow in evidenceRows) {
        final state = await evidenceStorage.verify(
          storageIdentifier: eRow['managed_storage_identifier'] as String,
          expectedSha256: eRow['sha256'] as String,
          expectedByteSize: eRow['byte_size'] as int,
        );
        if (state !=
            EvidenceVerificationState.verifiedUnchangedSinceIngestion) {
          throw StateError('Evidence verification failed: $state');
        }
      }

      // 3. Compute final hashes
      final finalizedAt = _clock();
      final canonicalBytes = _canonicalizer.canonicalBytes(draft, finalizedAt);

      final prevHash =
          await _getLatestChainHashForAgreement(txn, draft.agreementId);
      final recordHash = integrityEngine.hashRecord(canonicalBytes);
      final chainHash = integrityEngine.hashChain(
        recordHash: recordHash,
        previousChainHash: prevHash,
      );

      // 4. Update the row atomically
      await txn.update(
        'record_entries',
        {
          'state': RecordState.finalized.name,
          'finalized_at': finalizedAt.toIso8601String(),
          'record_hash': recordHash,
          'previous_chain_hash': prevHash,
          'chain_hash': chainHash,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      return draft.copyWith(
        state: RecordState.finalized,
        finalizedAt: finalizedAt,
        recordHash: recordHash,
        previousChainHash: prevHash,
        chainHash: chainHash,
      );
    });
  }

  @override
  Future<bool> hasEvidence(String evidenceId) async {
    final res = await _db
        .query('evidence_assets', where: 'id = ?', whereArgs: [evidenceId]);
    return res.isNotEmpty;
  }

  @override
  Future<String?> getLatestChainHashForAgreement(String agreementId) async {
    return _getLatestChainHashForAgreement(_db, agreementId);
  }

  Future<String?> _getLatestChainHashForAgreement(
    DatabaseExecutor executor,
    String agreementId,
  ) async {
    final rows = await executor.query(
      'record_entries',
      columns: ['chain_hash'],
      where: 'agreement_id = ? AND state = ?',
      whereArgs: [agreementId, RecordState.finalized.name],
      orderBy: 'finalized_at DESC, rowid DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['chain_hash'] as String?;
  }

  @override
  Future<List<RecordEntry>> allForAgreement(String agreementId) async {
    final rows = await _db.query(
      'record_entries',
      where: 'agreement_id = ?',
      whereArgs: [agreementId],
      orderBy: 'recorded_at ASC',
    );

    final results = <RecordEntry>[];
    for (final row in rows) {
      final id = row['id'] as String;

      final evidenceRows = await _db.rawQuery(
        '''
        SELECT e.id, e.sha256, e.capture_method, e.asset_role, e.deletion_state
        FROM record_evidence_links l
        JOIN evidence_assets e ON l.evidence_asset_id = e.id
        WHERE l.record_entry_id = ?
        ORDER BY l.display_order ASC
      ''',
        [id],
      );

      final evidence = evidenceRows
          .map(
            (eRow) => EvidenceReference(
              evidenceId: eRow['id'] as String,
              sha256: eRow['sha256'] as String,
              captureMethod: EvidenceCaptureMethod.values
                  .firstWhere((r) => r.name == eRow['capture_method']),
              assetRole: EvidenceAssetRole.values
                  .firstWhere((r) => r.name == eRow['asset_role']),
              bytesAvailable: eRow['deletion_state'] != 'deleted',
            ),
          )
          .toList();

      results.add(
        RecordEntry(
          id: id,
          workspaceId: row['workspace_id'] as String,
          agreementId: row['agreement_id'] as String,
          agreementVersionId: row['agreement_version_id'] as String,
          obligationId: row['obligation_id'] as String?,
          sourceClauseId: row['source_clause_id'] as String?,
          recordType:
              RecordType.values.firstWhere((t) => t.name == row['record_type']),
          title: row['title'] as String,
          factualDescription: row['factual_description'] as String,
          interpretationText: row['interpretation_text'] as String?,
          occurredAt: DateTime.parse(row['occurred_at'] as String),
          recordedAt: DateTime.parse(row['recorded_at'] as String),
          timezone: row['timezone'] as String,
          createdByPartyId: row['created_by_party_id'] as String,
          correctsRecordEntryId: row['corrects_record_entry_id'] as String?,
          state: RecordState.values.firstWhere((s) => s.name == row['state']),
          finalizedAt: row['finalized_at'] != null
              ? DateTime.parse(row['finalized_at'] as String)
              : null,
          recordHash: row['record_hash'] as String?,
          previousChainHash: row['previous_chain_hash'] as String?,
          chainHash: row['chain_hash'] as String?,
          evidence: evidence,
        ),
      );
    }
    return results;
  }
}
