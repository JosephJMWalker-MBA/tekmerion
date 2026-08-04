import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekmerion/src/core/database/app_database.dart';
import 'package:tekmerion/src/core/database/database_migrations.dart';
import 'package:tekmerion/src/core/integrity/integrity_engine.dart';
import 'package:tekmerion/src/core/storage/local_evidence_storage.dart';
import 'package:tekmerion/src/features/record/data/sqlite_record_repository.dart';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';
import 'package:tekmerion/src/features/record/domain/evidence_reference.dart';
import 'package:tekmerion/src/features/record/domain/record_entry.dart';

// Fake IntegrityEngine for testing
class _FakeIntegrityEngine implements IntegrityEngine {
  const _FakeIntegrityEngine();

  @override
  String hashRecord(List<int> canonicalBytes) =>
      'hash_${utf8.decode(canonicalBytes, allowMalformed: true)}';

  @override
  String hashChain({
    required String recordHash,
    required String? previousChainHash,
  }) {
    return previousChainHash == null
        ? 'chain_$recordHash'
        : 'chain_${previousChainHash}_$recordHash';
  }
}

void main() {
  group('sqlite record repository', () {
    late String dbPath;
    late Directory tempStorageDir;
    late SqliteRecordRepository repository;
    late LocalEvidenceStorage evidenceStorage;
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      dbPath = inMemoryDatabasePath;
      db = await DatabaseMigrations.openAndMigrate(dbPath);

      // We must mock AppDatabase instance for the repository since it uses a singleton
      // But AppDatabase.init handles the singleton, so we use it with a temp file for tests
      // However inMemoryDatabasePath doesn't work well with singletons between tests if not managed.
      // We will use a temp file database for safety.
      final tempDb = await Directory.systemTemp.createTemp('tek_db_');
      dbPath = '${tempDb.path}/test.db';
      await AppDatabase.init(dbPath);
      db = AppDatabase.instance;

      tempStorageDir = await Directory.systemTemp.createTemp('tekmerion_test_');
      evidenceStorage =
          LocalEvidenceStorage(getRootDirectory: () async => tempStorageDir);

      repository = SqliteRecordRepository(
        integrityEngine: const _FakeIntegrityEngine(),
        evidenceStorage: evidenceStorage,
        clock: () => DateTime.utc(2026, 8, 3, 20, 30),
      );
    });

    tearDown(() async {
      await AppDatabase.close();
      final tempDbFile = File(dbPath);
      if (await tempDbFile.exists()) {
        await tempDbFile.parent.delete(recursive: true);
      }
      if (await tempStorageDir.exists()) {
        await tempStorageDir.delete(recursive: true);
      }
    });

    Future<void> insertPrerequisites() async {
      await db.insert('agreements', {
        'id': 'a1',
        'title': 'Test Agreement',
        'agreement_type': 'lease',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('evidence_assets', {
        'id': 'e1',
        'original_filename': 'source.pdf',
        'sanitized_storage_filename': 'source.pdf',
        'mime_type': 'application/pdf',
        'byte_size': 100,
        'sha256': 'abc',
        'managed_storage_identifier': 'storage/e1',
        'capture_method': 'external',
        'asset_role': 'original',
        'imported_at': DateTime.now().toIso8601String(),
        'pre_ingestion_history_status': 'unknown',
        'deletion_state': 'active',
      });

      await db.insert('agreement_versions', {
        'id': 'v1',
        'agreement_id': 'a1',
        'source_evidence_asset_id': 'e1',
        'version_label': '1.0',
        'status': 'active',
        'imported_at': DateTime.now().toIso8601String(),
      });
    }

    Future<EvidenceEnvelope> ingestEvidence(
      List<int> bytes,
      String originalFilename,
    ) async {
      final env = await evidenceStorage.ingestCapturedBytes(
        bytes: Uint8List.fromList(bytes),
        originalFilename: originalFilename,
        mimeType: 'image/png',
      );
      await db.insert('evidence_assets', {
        'id': env.evidenceId,
        'original_filename': originalFilename,
        'sanitized_storage_filename': 'unknown',
        'mime_type': 'image/png',
        'byte_size': env.byteSize,
        'sha256': env.sha256,
        'managed_storage_identifier': env.storageIdentifier,
        'capture_method': env.captureMethod.name,
        'asset_role': env.assetRole.name,
        'imported_at': DateTime.now().toIso8601String(),
        'pre_ingestion_history_status': 'unknown',
        'deletion_state': 'active',
      });
      return env;
    }

    RecordEntry draft0({String id = 'r1'}) {
      return RecordEntry(
        id: id,
        workspaceId: 'w1',
        agreementId: 'a1',
        agreementVersionId: 'v1',
        recordType: RecordType.communicationSent,
        title: 'Notice sent',
        factualDescription: 'Sent an email',
        occurredAt: DateTime.utc(2026, 8, 1),
        recordedAt: DateTime.utc(2026, 8, 3, 20, 30),
        timezone: 'UTC',
        createdByPartyId: 'p1',
        state: RecordState.draft,
      );
    }

    test('one agreement and version can be inserted and read', () async {
      await insertPrerequisites();

      final rows = await db.query('agreements');
      expect(rows.length, equals(1));
      expect(rows.first['id'], equals('a1'));

      final versionRows = await db.query('agreement_versions');
      expect(versionRows.length, equals(1));
      expect(versionRows.first['id'], equals('v1'));
    });

    test('one clause and confirmed obligation preserve provenance', () async {
      await insertPrerequisites();

      await db.insert('clauses', {
        'id': 'c1',
        'agreement_version_id': 'v1',
        'source_text': 'Tenant shall pay rent.',
        'page_start': 1,
        'page_end': 1,
        'review_state': 'confirmed',
        'created_at': DateTime.now().toIso8601String(),
        'confirmed_at': DateTime.now().toIso8601String(),
      });

      await db.insert('obligations', {
        'id': 'o1',
        'agreement_id': 'a1',
        'source_clause_id': 'c1', // Provenance preserved
        'title': 'Pay Rent',
        'description': 'Pay rent monthly',
        'obligation_category': 'payment',
        'status': 'confirmed',
        'confirmed_at': DateTime.now().toIso8601String(),
      });

      final rows = await db.query('obligations');
      expect(rows.first['source_clause_id'], equals('c1'));
    });

    test('one evidence envelope can be persisted and retrieved exactly',
        () async {
      await insertPrerequisites();
      final env = await ingestEvidence([1, 2, 3], 'test.png');

      final draft = draft0().copyWith(
        evidence: [
          EvidenceReference(
            evidenceId: env.evidenceId,
            sha256: env.sha256,
            captureMethod: env.captureMethod,
            assetRole: env.assetRole,
            bytesAvailable: true,
          ),
        ],
      );

      await repository.saveDraft(draft);

      final retrieved = await repository.getById(draft.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.evidence.length, equals(1));
      expect(retrieved.evidence.first.sha256, equals(env.sha256));
    });

    test('finalizing a draft persists canonical hash and chain hash atomically',
        () async {
      await insertPrerequisites();
      final env = await ingestEvidence([1, 2, 3], 'test.png');

      final draft = draft0().copyWith(
        evidence: [
          EvidenceReference(
            evidenceId: env.evidenceId,
            sha256: env.sha256,
            captureMethod: env.captureMethod,
            assetRole: env.assetRole,
            bytesAvailable: true,
          ),
        ],
      );

      await repository.saveDraft(draft);

      final finalized = await repository.finalize(draft.id);

      expect(finalized.state, equals(RecordState.finalized));
      expect(finalized.recordHash, isNotNull);
      expect(finalized.chainHash, isNotNull);

      // Verify DB state
      final dbRow = (await db
              .query('record_entries', where: 'id = ?', whereArgs: [draft.id]))
          .first;
      expect(dbRow['state'], equals(RecordState.finalized.name));
      expect(dbRow['record_hash'], isNotNull);
    });

    test('finalized records reject protected-field updates', () async {
      await insertPrerequisites();
      final draft = draft0();
      await repository.saveDraft(draft);
      await repository.finalize(draft.id);

      expect(
        () => repository.updateDraft(draft.copyWith(title: 'Hacked Title')),
        throwsA(isA<StateError>()),
      );
    });

    test('missing evidence causes finalization rollback', () async {
      await insertPrerequisites();
      final env = await ingestEvidence([1, 2, 3], 'test.png');

      final draft = draft0().copyWith(
        evidence: [
          EvidenceReference(
            evidenceId: env.evidenceId,
            sha256: env.sha256,
            captureMethod: env.captureMethod,
            assetRole: env.assetRole,
            bytesAvailable: true,
          ),
        ],
      );

      await repository.saveDraft(draft);

      // Delete evidence out of band
      await evidenceStorage.deleteDraftAsset(env.storageIdentifier);

      await expectLater(
        repository.finalize(draft.id),
        throwsA(isA<StateError>()),
      );

      // Verify no partial finalization state exists
      final dbRow = (await db
              .query('record_entries', where: 'id = ?', whereArgs: [draft.id]))
          .first;
      expect(dbRow['state'], equals(RecordState.draft.name));
      expect(dbRow['record_hash'], isNull);
    });

    test('hash mismatch causes finalization rollback', () async {
      await insertPrerequisites();
      final env = await ingestEvidence([1, 2, 3], 'test.png');

      final draft = draft0().copyWith(
        evidence: [
          EvidenceReference(
            evidenceId: env.evidenceId,
            sha256: env.sha256,
            captureMethod: env.captureMethod,
            assetRole: env.assetRole,
            bytesAvailable: true,
          ),
        ],
      );

      await repository.saveDraft(draft);

      // Mutate the byte
      final file = File('${tempStorageDir.path}/${env.storageIdentifier}');
      await file.writeAsBytes([1, 2, 4]);

      await expectLater(
        repository.finalize(draft.id),
        throwsA(isA<StateError>()),
      );

      final dbRow = (await db
              .query('record_entries', where: 'id = ?', whereArgs: [draft.id]))
          .first;
      expect(dbRow['state'], equals(RecordState.draft.name));
    });

    test('record-evidence links persist in display order', () async {
      await insertPrerequisites();
      final env1 = await ingestEvidence([1], '1.png');
      final env2 = await ingestEvidence([2], '2.png');

      final draft = draft0().copyWith(
        evidence: [
          EvidenceReference(
            evidenceId: env2.evidenceId,
            sha256: env2.sha256,
            captureMethod: env2.captureMethod,
            assetRole: env2.assetRole,
            bytesAvailable: true,
          ),
          EvidenceReference(
            evidenceId: env1.evidenceId,
            sha256: env1.sha256,
            captureMethod: env1.captureMethod,
            assetRole: env1.assetRole,
            bytesAvailable: true,
          ),
        ],
      );

      await repository.saveDraft(draft);

      final retrieved = await repository.getById(draft.id);
      expect(retrieved!.evidence[0].evidenceId, equals(env2.evidenceId));
      expect(retrieved.evidence[1].evidenceId, equals(env1.evidenceId));
    });
  });
}
