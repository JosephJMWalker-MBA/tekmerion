import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekmerion/src/core/database/database_migrations.dart';
import 'package:tekmerion/src/features/obligation/data/sqlite_obligation_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation.dart';
import 'package:tekmerion/src/features/obligation/domain/schedule_rule.dart';

void main() {
  late Directory tempDir;
  late Database db;
  late SqliteObligationRepository repository;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('tekmerion_obligation_test');
    dbPath = p.join(tempDir.path, 'test.db');
    db = await DatabaseMigrations.openAndMigrate(dbPath);
    repository = SqliteObligationRepository((path) async => db, dbPath);

    // Insert required prerequisites (agreement, version, clause) to satisfy foreign keys
    await db.insert('agreements', {
      'id': 'a1',
      'title': 'Test Agreement',
      'agreement_type': 'lease',
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('agreement_versions', {
      'id': 'v1',
      'agreement_id': 'a1',
      'source_evidence_asset_id': 'e1',
      'version_label': '1.0',
      'status': 'active',
      'imported_at': DateTime.now().toIso8601String(),
    });

    await db.insert('clauses', {
      'id': 'c1',
      'agreement_version_id': 'v1',
      'source_text': 'Tenant shall pay rent',
      'page_start': 1,
      'page_end': 1,
      'review_state': 'confirmed',
      'created_at': DateTime.now().toIso8601String(),
    });
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('SqliteObligationRepository createDraftObligation persists exactly',
      () async {
    final obligation = Obligation(
      id: 'o1',
      agreementId: 'a1',
      sourceClauseId: 'c1',
      sourceType: ObligationSourceType.contractual,
      responsiblePartyId: 'tenant',
      title: 'Pay Rent',
      description: 'Monthly rent payment',
      obligationCategory: 'financial',
      status: ObligationStatus.draft,
      createdAt: DateTime.now(),
    );

    await repository.createDraftObligation(obligation);

    final fetched = await repository.getObligationById('o1');
    expect(fetched, isNotNull);
    expect(fetched!.title, 'Pay Rent');
    expect(fetched.status, ObligationStatus.draft);
  });

  test('SqliteObligationRepository rejects creating non-draft obligation',
      () async {
    final obligation = Obligation(
      id: 'o2',
      agreementId: 'a1',
      sourceClauseId: 'c1',
      sourceType: ObligationSourceType.contractual,
      title: 'Pay Rent',
      description: 'Monthly rent payment',
      obligationCategory: 'financial',
      status: ObligationStatus.confirmed,
      createdAt: DateTime.now(),
      confirmedAt: DateTime.now(),
    );

    expect(
      () => repository.createDraftObligation(obligation),
      throwsArgumentError,
    );
  });

  test(
      'SqliteObligationRepository confirmObligation transitions state and sets confirmedAt',
      () async {
    final obligation = Obligation(
      id: 'o3',
      agreementId: 'a1',
      sourceClauseId: 'c1',
      sourceType: ObligationSourceType.contractual,
      title: 'Pay Rent',
      description: 'Monthly rent payment',
      obligationCategory: 'financial',
      status: ObligationStatus.draft,
      createdAt: DateTime.now(),
    );

    await repository.createDraftObligation(obligation);
    await repository.confirmObligation('o3');

    final fetched = await repository.getObligationById('o3');
    expect(fetched!.status, ObligationStatus.confirmed);
    expect(fetched.confirmedAt, isNotNull);
  });

  test('SqliteObligationRepository updateDraftObligation saves changes',
      () async {
    final obligation = Obligation(
      id: 'o4',
      agreementId: 'a1',
      sourceClauseId: 'c1',
      sourceType: ObligationSourceType.contractual,
      title: 'Pay Rent',
      description: 'Monthly rent payment',
      obligationCategory: 'financial',
      status: ObligationStatus.draft,
      createdAt: DateTime.now(),
    );

    await repository.createDraftObligation(obligation);

    final updated = obligation.copyWith(title: 'Pay Updated Rent');
    await repository.updateDraftObligation(updated);

    final fetched = await repository.getObligationById('o4');
    expect(fetched!.title, 'Pay Updated Rent');
  });

  test(
      'SqliteObligationRepository updateDraftObligation rejects if not in draft',
      () async {
    final obligation = Obligation(
      id: 'o5',
      agreementId: 'a1',
      sourceClauseId: 'c1',
      sourceType: ObligationSourceType.contractual,
      title: 'Pay Rent',
      description: 'Monthly rent payment',
      obligationCategory: 'financial',
      status: ObligationStatus.draft,
      createdAt: DateTime.now(),
    );

    await repository.createDraftObligation(obligation);
    await repository.confirmObligation('o5');

    // Attempt to update the confirmed obligation
    final updated = obligation.copyWith(
      title: 'Changed title',
      status: ObligationStatus.confirmed,
    );
    expect(() => repository.updateDraftObligation(updated), throwsStateError);
  });

  test(
      'SqliteObligationRepository createScheduleRule persists structured recurrence',
      () async {
    final obligation = Obligation(
      id: 'o6',
      agreementId: 'a1',
      sourceClauseId: 'c1',
      sourceType: ObligationSourceType.contractual,
      title: 'Pay Rent',
      description: 'Monthly rent payment',
      obligationCategory: 'financial',
      status: ObligationStatus.draft,
      createdAt: DateTime.now(),
    );
    await repository.createDraftObligation(obligation);

    final rule = ScheduleRule(
      id: 'sr1',
      obligationId: 'o6',
      ruleType: ScheduleRuleType.monthlyDayOfMonth,
      timezone: 'America/New_York',
      startAt: DateTime(2026, 1, 1),
      recurrenceExpression: '1',
      leadTimeSeconds: 86400,
      gracePeriodSeconds: 0,
      confirmedAt: DateTime.now(),
    );

    await repository.createScheduleRule(rule);

    final fetched = await repository.getScheduleRuleForObligation('o6');
    expect(fetched, isNotNull);
    expect(fetched!.ruleType, ScheduleRuleType.monthlyDayOfMonth);
    expect(fetched.recurrenceExpression, '1');
    expect(fetched.timezone, 'America/New_York');
  });
}
