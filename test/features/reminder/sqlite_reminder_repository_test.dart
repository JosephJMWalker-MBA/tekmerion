import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekmerion/src/core/database/database_migrations.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';
import 'package:tekmerion/src/features/reminder/infrastructure/sqlite_reminder_repository.dart';

void main() {
  group('SqliteReminderRepository', () {
    late SqliteReminderRepository repository;
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await DatabaseMigrations.openAndMigrate(inMemoryDatabasePath);
      repository =
          SqliteReminderRepository((_) async => db, inMemoryDatabasePath);

      // Setup required foreign key dependencies
      await db.insert('agreements', {
        'id': 'a1',
        'title': 'Test Agreement',
        'agreement_type': 'lease',
        'status': 'active',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      await db.insert('obligations', {
        'id': 'o1',
        'agreement_id': 'a1',
        'source_type': 'contractual',
        'title': 'Obligation',
        'description': 'Description',
        'obligation_category': 'financial',
        'status': 'active',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      await db.insert('schedule_rules', {
        'id': 'sr1',
        'obligation_id': 'o1',
        'rule_type': 'oneTime',
        'timezone': 'UTC',
        'start_at': DateTime.now().toUtc().toIso8601String(),
        'lead_time_seconds': 0,
        'grace_period_seconds': 0,
        'confirmed_at': DateTime.now().toUtc().toIso8601String(),
      });
    });

    tearDown(() async {
      await db.close();
    });

    ReminderInstance createTestReminder({
      String id = 'r1',
      String occurrenceKey = 'key1',
      ReminderState state = ReminderState.scheduled,
      int generationVersion = 1,
      DateTime? dueAt,
      DateTime? remindAt,
    }) {
      final now = DateTime.now().toUtc();
      final finalDueAt = dueAt ?? now.add(const Duration(days: 1));
      return ReminderInstance(
        id: id,
        agreementId: 'a1',
        obligationId: 'o1',
        scheduleRuleId: 'sr1',
        occurrenceKey: occurrenceKey,
        dueAt: finalDueAt,
        remindAt: remindAt ?? finalDueAt.subtract(const Duration(hours: 1)),
        timezone: 'UTC',
        state: state,
        generationVersion: generationVersion,
        generatedAt: now,
        notificationState: NotificationSchedulingState.notRequested,
        title: 'Title',
        body: 'Body',
        provenanceSummary: 'Provenance',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('insertIfAbsent ignores duplicate by occurrenceKey', () async {
      final r1 = createTestReminder();
      await repository.insertIfAbsent(r1);

      // Try to insert a conflicting reminder (same rule & occurrence)
      final r2 = createTestReminder(id: 'r2');
      await repository.insertIfAbsent(r2); // Should be ignored

      final results = await db.query('reminders');
      expect(results.length, equals(1));
      expect(results.first['id'], equals('r1'));
    });

    test('insertBatchIfAbsent ignores duplicates', () async {
      final r1 = createTestReminder(id: 'r1', occurrenceKey: 'k1');
      final r2 = createTestReminder(id: 'r2', occurrenceKey: 'k2');
      final r1Dup = createTestReminder(id: 'r3', occurrenceKey: 'k1');

      await repository.insertBatchIfAbsent([r1, r2, r1Dup]);

      final results = await db.query('reminders');
      expect(results.length, equals(2));
      final ids = results.map((e) => e['id']).toList();
      expect(ids, containsAll(['r1', 'r2']));
    });

    group('transitionState timestamp correctness', () {
      final occurred = DateTime.now().toUtc().add(const Duration(days: 1));

      Future<void> assertTransition(ReminderState targetState,
          DateTime? Function(ReminderInstance) getTimestamp) async {
        final id = 'r_${targetState.name}';
        final r = createTestReminder(id: id, state: ReminderState.scheduled);
        await repository.insertIfAbsent(r);

        await repository.transitionState(
          reminderId: id,
          expectedCurrentState: ReminderState.scheduled,
          targetState: targetState,
          occurredAt: occurred,
        );

        final fetched = await repository.getById(id);
        expect(fetched!.state, equals(targetState));
        expect(getTimestamp(fetched), equals(occurred));
        expect(fetched.updatedAt, equals(occurred));

        // Assert other terminal timestamps remain null
        if (targetState != ReminderState.acknowledged)
          expect(fetched.acknowledgedAt, isNull);
        if (targetState != ReminderState.completed)
          expect(fetched.completedAt, isNull);
        if (targetState != ReminderState.dismissed)
          expect(fetched.dismissedAt, isNull);
        if (targetState != ReminderState.cancelled)
          expect(fetched.cancelledAt, isNull);
        if (targetState != ReminderState.superseded)
          expect(fetched.supersededAt, isNull);
        if (targetState != ReminderState.expired)
          expect(fetched.expiredAt, isNull);
      }

      test(
          'acknowledged writes acknowledged_at',
          () => assertTransition(
              ReminderState.acknowledged, (r) => r.acknowledgedAt));
      test(
          'completed writes completed_at',
          () =>
              assertTransition(ReminderState.completed, (r) => r.completedAt));
      test(
          'dismissed writes dismissed_at',
          () =>
              assertTransition(ReminderState.dismissed, (r) => r.dismissedAt));
      test(
          'cancelled writes cancelled_at',
          () =>
              assertTransition(ReminderState.cancelled, (r) => r.cancelledAt));
      test(
          'superseded writes superseded_at',
          () => assertTransition(
              ReminderState.superseded, (r) => r.supersededAt));
      test('expired writes expired_at',
          () => assertTransition(ReminderState.expired, (r) => r.expiredAt));
    });

    test('transitionState fails if current state does not match', () async {
      final r1 = createTestReminder(state: ReminderState.scheduled);
      await repository.insertIfAbsent(r1);

      final occurred = DateTime.now().toUtc();
      expect(
        () => repository.transitionState(
          reminderId: 'r1',
          expectedCurrentState: ReminderState.acknowledged,
          targetState: ReminderState.completed,
          occurredAt: occurred,
        ),
        throwsStateError,
      );
    });

    test('markNotificationScheduled updates notification fields', () async {
      final r1 = createTestReminder();
      await repository.insertIfAbsent(r1);

      final scheduledAt = DateTime.now().toUtc();
      await repository.markNotificationScheduled(
        reminderId: 'r1',
        localNotificationId: 1001,
        scheduledAt: scheduledAt,
      );

      final fetched = await repository.getById('r1');
      expect(fetched!.notificationState,
          equals(NotificationSchedulingState.scheduled));
      expect(fetched.localNotificationId, equals(1001));
      expect(fetched.notificationScheduledAt, equals(scheduledAt));
    });

    test('cancelFutureForObligation cancels active reminders', () async {
      final r1 = createTestReminder(
          id: 'r1', occurrenceKey: 'k1', state: ReminderState.scheduled);
      final r2 = createTestReminder(
          id: 'r2', occurrenceKey: 'k2', state: ReminderState.scheduled);
      final r3 = createTestReminder(
          id: 'r3', occurrenceKey: 'k3', state: ReminderState.completed);
      await repository.insertBatchIfAbsent([r1, r2, r3]);

      final cancelledAt = DateTime.now().toUtc();
      await repository.cancelFutureForObligation(
        obligationId: 'o1',
        cancelledAt: cancelledAt,
      );

      final fetched = await repository.getForObligation('o1');

      final fetched1 = fetched.firstWhere((e) => e.id == 'r1');
      expect(fetched1.state, equals(ReminderState.cancelled));
      expect(fetched1.cancelledAt, equals(cancelledAt));

      final fetched2 = fetched.firstWhere((e) => e.id == 'r2');
      expect(fetched2.state, equals(ReminderState.cancelled));
      expect(fetched2.cancelledAt, equals(cancelledAt));

      final fetched3 = fetched.firstWhere((e) => e.id == 'r3');
      expect(fetched3.state, equals(ReminderState.completed));
      expect(fetched3.cancelledAt, isNull);
    });

    test('supersedeFutureForRule supersedes active old-version reminders',
        () async {
      final r1 = createTestReminder(
          id: 'r1',
          occurrenceKey: 'k1',
          generationVersion: 1,
          state: ReminderState.scheduled);
      final r2 = createTestReminder(
          id: 'r2',
          occurrenceKey: 'k2',
          generationVersion: 2,
          state: ReminderState.scheduled);
      await repository.insertBatchIfAbsent([r1, r2]);

      final supersededAt = DateTime.now().toUtc();
      await repository.supersedeFutureForRule(
        scheduleRuleId: 'sr1',
        newGenerationVersion: 2,
        supersededAt: supersededAt,
      );

      final fetched = await repository.getForScheduleRule('sr1');

      final fetched1 = fetched.firstWhere((e) => e.id == 'r1');
      expect(fetched1.state, equals(ReminderState.superseded));
      expect(fetched1.supersededAt, equals(supersededAt));

      final fetched2 = fetched.firstWhere((e) => e.id == 'r2');
      expect(fetched2.state, equals(ReminderState.scheduled));
      expect(fetched2.supersededAt, isNull);
    });

    test('getToday returns correctly', () async {
      final now = DateTime.now().toUtc();
      final r1 = createTestReminder(
          id: 'r1',
          occurrenceKey: 'k1',
          dueAt: now.subtract(const Duration(days: 1)),
          remindAt: now.subtract(const Duration(days: 2)),
          state: ReminderState.scheduled); // past due
      final r2 = createTestReminder(
          id: 'r2',
          occurrenceKey: 'k2',
          dueAt: now.add(const Duration(days: 1)),
          state: ReminderState.scheduled); // future
      final r3 = createTestReminder(
          id: 'r3',
          occurrenceKey: 'k3',
          dueAt: now.subtract(const Duration(days: 1)),
          remindAt: now.subtract(const Duration(days: 2)),
          state: ReminderState.completed); // past due but completed

      await repository.insertBatchIfAbsent([r1, r2, r3]);

      final todayList = await repository.getToday(now);
      expect(todayList.length, equals(1));
      expect(todayList.first.id, equals('r1'));
    });
  });
}
