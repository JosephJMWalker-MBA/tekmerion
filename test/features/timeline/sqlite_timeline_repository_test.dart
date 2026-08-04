import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekmerion/src/core/database/database_schema.dart';
import 'package:tekmerion/src/features/timeline/data/sqlite_timeline_repository.dart';
import 'package:tekmerion/src/features/timeline/domain/timeline_event.dart';

void main() {
  late Database db;
  late SqliteTimelineRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    for (final statement in DatabaseSchema.phase1Migration) {
      await db.execute(statement);
    }
    repo = SqliteTimelineRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'getTimelineForAgreement returns chronologically sorted events from canonical tables',
      () async {
    final now = DateTime.now().toUtc();

    // Insert an agreement
    await db.insert('agreements', {
      'id': 'a1',
      'title': 'Test Lease',
      'agreement_type': 'lease',
      'status': 'active',
      'created_at': now.subtract(const Duration(days: 10)).toIso8601String(),
    });

    // Insert an agreement version
    await db.insert('agreement_versions', {
      'id': 'v1',
      'agreement_id': 'a1',
      'source_evidence_asset_id': 'e1',
      'version_label': 'v1',
      'status': 'active',
      'imported_at': now.subtract(const Duration(days: 9)).toIso8601String(),
    });

    // Insert a clause
    await db.insert('clauses', {
      'id': 'c1',
      'agreement_version_id': 'v1',
      'source_text': 'Pay rent',
      'page_start': 1,
      'page_end': 1,
      'review_state': 'confirmed',
      'created_at': now.subtract(const Duration(days: 8)).toIso8601String(),
      'confirmed_at': now.subtract(const Duration(days: 7)).toIso8601String(),
    });

    // Insert an obligation
    await db.insert('obligations', {
      'id': 'o1',
      'agreement_id': 'a1',
      'source_type': 'contractual',
      'title': 'Pay Rent',
      'description': 'Pay \$1000',
      'obligation_category': 'payment',
      'status': 'confirmed',
      'created_at': now.subtract(const Duration(days: 6)).toIso8601String(),
      'confirmed_at': now.subtract(const Duration(days: 5)).toIso8601String(),
    });

    // Insert a record entry (ObligationCompleted & RecordFinalized)
    await db.insert('record_entries', {
      'id': 'r1',
      'workspace_id': 'w1',
      'agreement_id': 'a1',
      'agreement_version_id': 'v1',
      'obligation_id': 'o1',
      'record_type': 'performance',
      'title': 'Rent Paid',
      'factual_description': 'Transferred \$1000',
      'occurred_at': now.subtract(const Duration(days: 4)).toIso8601String(),
      'recorded_at': now.subtract(const Duration(days: 3)).toIso8601String(),
      'timezone': 'UTC',
      'created_by_party_id': 'self',
      'state': 'finalized',
      'canonicalization_version': '1',
      'signature_state': 'none',
      'finalized_at': now.subtract(const Duration(days: 2)).toIso8601String(),
    });

    // Fetch timeline
    final events = await repo.getTimelineForAgreement('a1');

    // Should have: AgreementImported, AgreementVersionCreated, ClauseConfirmed, ObligationConfirmed, ObligationCompleted, RecordFinalized
    expect(events.length, 6);

    // Latest first by recordedAt
    expect(events[0].eventType, TimelineEventType.recordFinalized);
    expect(events[1].eventType, TimelineEventType.obligationCompleted);
    expect(events[2].eventType, TimelineEventType.obligationConfirmed);
    expect(events[3].eventType, TimelineEventType.clauseConfirmed);
    expect(events[4].eventType, TimelineEventType.agreementVersionCreated);
    expect(events[5].eventType, TimelineEventType.agreementImported);

    // Test a specific mapping
    expect(events[2].title, 'Obligation created');
    expect(events[2].sourceObjectType, 'Obligation');
    expect(events[2].sourceObjectId, 'o1');
  });

  test('empty state returns empty list', () async {
    final events = await repo.getTimelineForAgreement('nonexistent');
    expect(events, isEmpty);
  });

  test('equal timestamps sort deterministically by priority then id', () async {
    final now = DateTime.now().toUtc();
    
    await db.insert('agreements', {
      'id': 'a2',
      'title': 'Test',
      'agreement_type': 'lease',
      'status': 'active',
      'created_at': now.toIso8601String(),
    });

    await db.insert('record_entries', {
      'id': 'r2_a',
      'workspace_id': 'w1',
      'agreement_id': 'a2',
      'record_type': 'performance',
      'agreement_version_id': 'v1',
      'title': 'A',
      'factual_description': 'Test',
      'occurred_at': now.toIso8601String(),
      'recorded_at': now.toIso8601String(),
      'timezone': 'UTC',
      'created_by_party_id': 'self',
      'state': 'finalized',
      'finalized_at': now.toIso8601String(),
      'canonicalization_version': '1',
      'signature_state': 'none',
      'obligation_id': 'o1',
    });

    await db.insert('record_entries', {
      'id': 'r2_b',
      'workspace_id': 'w1',
      'agreement_id': 'a2',
      'record_type': 'performance',
      'agreement_version_id': 'v1',
      'title': 'B',
      'factual_description': 'Test',
      'occurred_at': now.toIso8601String(),
      'recorded_at': now.toIso8601String(),
      'timezone': 'UTC',
      'created_by_party_id': 'self',
      'state': 'finalized',
      'finalized_at': now.toIso8601String(),
      'canonicalization_version': '1',
      'signature_state': 'none',
      'obligation_id': 'o1',
    });

    final events = await repo.getTimelineForAgreement('a2');
    
    final completionEvents = events.where((e) => e.eventType == TimelineEventType.obligationCompleted).toList();
    expect(completionEvents[0].id, 'r2_b_completed');
    expect(completionEvents[1].id, 'r2_a_completed');

    final finalizeEvents = events.where((e) => e.eventType == TimelineEventType.recordFinalized).toList();
    expect(finalizeEvents[0].id, 'r2_b_finalized');
    expect(finalizeEvents[1].id, 'r2_a_finalized');
  });

  test('no orphan source references and no duplicate event identity', () async {
    final now = DateTime.now().toUtc();
    await db.insert('agreements', {
      'id': 'a3',
      'title': 'Test',
      'agreement_type': 'lease',
      'status': 'active',
      'created_at': now.toIso8601String(),
    });
    
    await db.insert('evidence_assets', {
      'id': 'e1',
      'original_filename': 'receipt.jpg',
      'sanitized_storage_filename': 'receipt.jpg',
      'mime_type': 'image/jpeg',
      'byte_size': 100,
      'sha256': 'hash1',
      'managed_storage_identifier': 'path/to/e1',
      'capture_method': 'external_import',
      'asset_role': 'primary',
      'imported_at': now.toIso8601String(),
      'pre_ingestion_history_status': 'unknown',
      'deletion_state': 'active',
    });

    await db.insert('record_entries', {
      'id': 'r3',
      'workspace_id': 'w1',
      'agreement_id': 'a3',
      'record_type': 'performance',
      'agreement_version_id': 'v1',
      'title': 'C',
      'factual_description': 'Test',
      'occurred_at': now.toIso8601String(),
      'recorded_at': now.toIso8601String(),
      'timezone': 'UTC',
      'created_by_party_id': 'self',
      'state': 'finalized',
      'finalized_at': now.toIso8601String(),
      'canonicalization_version': '1',
      'signature_state': 'none',
      'obligation_id': 'o1',
    });

    await db.insert('record_evidence_links', {
      'id': 'rel1',
      'record_entry_id': 'r3',
      'evidence_asset_id': 'e1',
      'relationship_type': 'primary',
      'display_order': 0,
    });

    final events = await repo.getTimelineForAgreement('a3');
    
    final ids = events.map((e) => e.id).toSet();
    expect(ids.length, events.length);

    final evEvent = events.firstWhere((e) => e.eventType == TimelineEventType.evidenceAttached);
    expect(evEvent.sourceObjectType, 'EvidenceAsset');
    expect(evEvent.sourceObjectId, 'e1');
  });
}
