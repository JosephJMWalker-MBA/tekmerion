import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekmerion/src/core/database/database_migrations.dart';
import 'package:tekmerion/src/features/clause/data/sqlite_clause_repository.dart';
import 'package:tekmerion/src/features/clause/domain/clause.dart';

void main() {
  group('SqliteClauseRepository', () {
    late SqliteClauseRepository repository;
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await DatabaseMigrations.openAndMigrate(inMemoryDatabasePath);
      repository =
          SqliteClauseRepository((_) async => db, inMemoryDatabasePath);

      // Setup required foreign key dependencies
      await db.insert('agreements', {
        'id': 'a1',
        'title': 'Test Agreement',
        'agreement_type': 'lease',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('evidence_assets', {
        'id': 'e1',
        'original_filename': 'test.pdf',
        'sanitized_storage_filename': 'test.pdf',
        'mime_type': 'application/pdf',
        'byte_size': 100,
        'sha256': 'abc',
        'managed_storage_identifier': 'test',
        'capture_method': 'inAppCapture',
        'asset_role': 'original',
        'imported_at': DateTime.now().toIso8601String(),
        'pre_ingestion_history_status': 'unknown',
        'deletion_state': 'active',
      });
      await db.insert('agreement_versions', {
        'id': 'v1',
        'agreement_id': 'a1',
        'source_evidence_asset_id': 'e1',
        'version_label': 'Initial',
        'status': 'active',
        'imported_at': DateTime.now().toIso8601String(),
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('createDraftClause persists exactly', () async {
      final draft = Clause(
        id: 'c1',
        agreementVersionId: 'v1',
        sourceText: 'Draft content',
        pageStart: 1,
        pageEnd: 1,
        reviewState: ClauseReviewState.draft,
        createdAt: DateTime.now(),
      );

      await repository.createDraftClause(draft);

      final fetched = await repository.getClauseById('c1');
      expect(fetched, isNotNull);
      expect(fetched!.sourceText, equals('Draft content'));
      expect(fetched.reviewState, equals(ClauseReviewState.draft));
    });

    test('createDraftClause rejects non-draft states', () async {
      final confirmed = Clause(
        id: 'c2',
        agreementVersionId: 'v1',
        sourceText: 'Content',
        pageStart: 1,
        pageEnd: 1,
        reviewState: ClauseReviewState.confirmed,
        createdAt: DateTime.now(),
        confirmedAt: DateTime.now(),
      );

      expect(
        () => repository.createDraftClause(confirmed),
        throwsArgumentError,
      );
    });

    test('updateDraftClause saves changes', () async {
      final draft = Clause(
        id: 'c1',
        agreementVersionId: 'v1',
        sourceText: 'Old text',
        pageStart: 1,
        pageEnd: 1,
        reviewState: ClauseReviewState.draft,
        createdAt: DateTime.now(),
      );
      await repository.createDraftClause(draft);

      final updated =
          draft.copyWith(sourceText: 'New text', pageStart: 2, pageEnd: 2);
      await repository.updateDraftClause(updated);

      final fetched = await repository.getClauseById('c1');
      expect(fetched!.sourceText, equals('New text'));
      expect(fetched.pageStart, equals(2));
      expect(fetched.pageEnd, equals(2));
    });

    test('updateDraftClause rejects if clause not in draft state', () async {
      final draft = Clause(
        id: 'c1',
        agreementVersionId: 'v1',
        sourceText: 'Text',
        pageStart: 1,
        pageEnd: 1,
        reviewState: ClauseReviewState.draft,
        createdAt: DateTime.now(),
      );
      await repository.createDraftClause(draft);
      await repository.confirmClause('c1');

      final updated = draft.copyWith(sourceText: 'New text');
      expect(
        () => repository.updateDraftClause(updated),
        throwsStateError,
      );
    });

    test('confirmClause transitions state and sets confirmedAt', () async {
      final draft = Clause(
        id: 'c1',
        agreementVersionId: 'v1',
        sourceText: 'Text',
        pageStart: 1,
        pageEnd: 1,
        reviewState: ClauseReviewState.draft,
        createdAt: DateTime.now(),
      );
      await repository.createDraftClause(draft);

      await repository.confirmClause('c1');

      final fetched = await repository.getClauseById('c1');
      expect(fetched!.reviewState, equals(ClauseReviewState.confirmed));
      expect(fetched.confirmedAt, isNotNull);
    });

    test('getClausesForAgreementVersion returns clauses in order', () async {
      final c2 = Clause(
        id: 'c2',
        agreementVersionId: 'v1',
        sourceText: 'Page 2',
        pageStart: 2,
        pageEnd: 2,
        reviewState: ClauseReviewState.draft,
        createdAt: DateTime.now(),
      );
      final c1 = Clause(
        id: 'c1',
        agreementVersionId: 'v1',
        sourceText: 'Page 1',
        pageStart: 1,
        pageEnd: 1,
        reviewState: ClauseReviewState.draft,
        createdAt: DateTime.now(),
      );

      await repository.createDraftClause(c2);
      await repository.createDraftClause(c1);

      final list = await repository.getClausesForAgreementVersion('v1');
      expect(list.length, equals(2));
      expect(list[0].id, equals('c1')); // Page 1 first
      expect(list[1].id, equals('c2')); // Page 2 second
    });
  });
}
