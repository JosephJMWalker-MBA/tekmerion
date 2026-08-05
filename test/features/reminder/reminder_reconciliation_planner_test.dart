import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reconciliation_plan.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_reconciliation_planner.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';

void main() {
  group('ReminderReconciliationPlanner', () {
    late ReminderReconciliationPlanner planner;
    late DateTime currentUtc;

    setUp(() {
      planner = ReminderReconciliationPlanner();
      currentUtc = DateTime.utc(2026, 1, 1, 12, 0);
    });

    ReminderInstance buildReminder({
      required String id,
      required String obligationId,
      required String scheduleRuleId,
      required String occurrenceKey,
      required DateTime remindAt,
      ReminderState state = ReminderState.scheduled,
      int? localNotificationId,
    }) {
      return ReminderInstance(
        id: id,
        agreementId: 'a1',
        obligationId: obligationId,
        scheduleRuleId: scheduleRuleId,
        occurrenceKey: occurrenceKey,
        dueAt: remindAt.add(const Duration(hours: 1)),
        remindAt: remindAt,
        timezone: 'UTC',
        state: state,
        generationVersion: 1,
        generatedAt: currentUtc.subtract(const Duration(days: 1)),
        localNotificationId: localNotificationId,
        notificationState: NotificationSchedulingState.notRequested,
        title: 'Title',
        body: 'Body',
        provenanceSummary: 'Summary',
        createdAt: currentUtc.subtract(const Duration(days: 1)),
        updatedAt: currentUtc.subtract(const Duration(days: 1)),
      );
    }

    test('empty inputs produce empty plan', () {
      final plan = planner.createPlan(
        persistedReminders: [],
        candidateReminders: [],
        currentUtc: currentUtc,
        windowStartUtc: currentUtc,
        windowEndUtc: currentUtc.add(const Duration(days: 90)),
        fulfilledObligationIds: {},
        supersededScheduleRuleIds: {},
      );

      expect(plan.operations, isEmpty);
    });

    test('new candidate inserted', () {
      final candidate = buildReminder(
        id: 'r1',
        obligationId: 'o1',
        scheduleRuleId: 'sr1',
        occurrenceKey: 'key1',
        remindAt: currentUtc.add(const Duration(days: 5)),
      );

      final plan = planner.createPlan(
        persistedReminders: [],
        candidateReminders: [candidate],
        currentUtc: currentUtc,
        windowStartUtc: currentUtc,
        windowEndUtc: currentUtc.add(const Duration(days: 90)),
        fulfilledObligationIds: {},
        supersededScheduleRuleIds: {},
      );

      expect(plan.inserts.length, 1);
      final insert = plan.inserts.first;
      expect(insert.reminder, candidate);
      expect(insert.reason,
          ReconciliationReasonCode.candidateMissingFromPersistence);
      expect(insert.localNotificationId, isNotNull);
    });

    test('matching reminder preserved', () {
      final persisted = buildReminder(
        id: 'r1',
        obligationId: 'o1',
        scheduleRuleId: 'sr1',
        occurrenceKey: 'key1',
        remindAt: currentUtc.add(const Duration(days: 5)),
        localNotificationId: 12345,
      );

      final plan = planner.createPlan(
        persistedReminders: [persisted],
        candidateReminders: [persisted],
        currentUtc: currentUtc,
        windowStartUtc: currentUtc,
        windowEndUtc: currentUtc.add(const Duration(days: 90)),
        fulfilledObligationIds: {},
        supersededScheduleRuleIds: {},
      );

      expect(plan.operations.length, 1);
      expect(plan.preserves.length, 1);
      final preserve = plan.preserves.first;
      expect(preserve.reminder, persisted);
      expect(
          preserve.reason, ReconciliationReasonCode.occurrenceIdentityMatched);
      expect(preserve.localNotificationId, 12345);
    });

    test('future unmatched reminder superseded if rule superseded', () {
      final persisted = buildReminder(
        id: 'r1',
        obligationId: 'o1',
        scheduleRuleId: 'sr1', // old rule
        occurrenceKey: 'key1',
        remindAt: currentUtc.add(const Duration(days: 5)),
        localNotificationId: 12345,
      );

      final candidate = buildReminder(
        id: 'r2',
        obligationId: 'o1',
        scheduleRuleId: 'sr2', // new rule
        occurrenceKey: 'key2', // different occurrence
        remindAt: currentUtc.add(const Duration(days: 6)),
      );

      final plan = planner.createPlan(
        persistedReminders: [persisted],
        candidateReminders: [candidate],
        currentUtc: currentUtc,
        windowStartUtc: currentUtc,
        windowEndUtc: currentUtc.add(const Duration(days: 90)),
        fulfilledObligationIds: {},
        supersededScheduleRuleIds: {'sr1'},
      );

      expect(plan.supersedes.length, 1);
      expect(plan.supersedes.first.reminder, persisted);
      expect(plan.supersedes.first.reason,
          ReconciliationReasonCode.ruleSupersededAndOccurrenceFuture);

      expect(plan.inserts.length, 1);
      expect(plan.inserts.first.reminder, candidate);
    });

    test('fulfilled obligation cancels only future active reminders', () {
      final past = buildReminder(
        id: 'p1',
        obligationId: 'o1',
        scheduleRuleId: 'sr1',
        occurrenceKey: 'past_key',
        remindAt: currentUtc.subtract(const Duration(days: 5)),
      );

      final futureActive = buildReminder(
        id: 'f1',
        obligationId: 'o1',
        scheduleRuleId: 'sr1',
        occurrenceKey: 'future_key',
        remindAt: currentUtc.add(const Duration(days: 5)),
      );

      final plan = planner.createPlan(
        persistedReminders: [past, futureActive],
        candidateReminders: [],
        currentUtc: currentUtc,
        windowStartUtc: currentUtc,
        windowEndUtc: currentUtc.add(const Duration(days: 90)),
        fulfilledObligationIds: {'o1'},
        supersededScheduleRuleIds: {},
      );

      expect(plan.historicalUnchanged.length, 1);
      expect(plan.historicalUnchanged.first.reminder, past);

      expect(plan.cancels.length, 1);
      expect(plan.cancels.first.reminder, futureActive);
      expect(plan.cancels.first.reason,
          ReconciliationReasonCode.obligationFulfilled);
    });

    test('terminal unmatched reminder preserved', () {
      final terminal = buildReminder(
        id: 't1',
        obligationId: 'o1',
        scheduleRuleId: 'sr1',
        occurrenceKey: 'term_key',
        remindAt: currentUtc.add(const Duration(days: 5)),
        state: ReminderState.completed,
      );

      final plan = planner.createPlan(
        persistedReminders: [terminal],
        candidateReminders: [],
        currentUtc: currentUtc,
        windowStartUtc: currentUtc,
        windowEndUtc: currentUtc.add(const Duration(days: 90)),
        fulfilledObligationIds: {},
        supersededScheduleRuleIds: {
          'sr1'
        }, // Even if rule superseded, terminal state protects it
      );

      expect(plan.historicalUnchanged.length, 1);
      expect(plan.historicalUnchanged.first.reason,
          ReconciliationReasonCode.terminalHistoryPreserved);
      expect(plan.supersedes, isEmpty);
    });
  });
}
