import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/reminder/application/local_notification_adapter.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_reconciliation_service.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_permission_state.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reconciliation_plan.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_reconciliation_planner.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_repository.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';

class FakeLocalNotificationAdapter implements LocalNotificationAdapter {
  NotificationPermissionState permission = NotificationPermissionState.granted;
  bool shouldFailSchedule = false;
  int scheduleCallCount = 0;
  int cancelCallCount = 0;

  @override
  Future<NotificationPermissionState> inspectPermissionState() async =>
      permission;

  @override
  Future<NotificationPermissionState> requestPermission() async => permission;

  @override
  Future<NotificationSchedulingState> scheduleNotification(
      NotificationScheduleRequest request) async {
    scheduleCallCount++;
    if (shouldFailSchedule) {
      throw Exception('Platform failure');
    }
    return NotificationSchedulingState.scheduled;
  }

  @override
  Future<void> cancelNotification(int notificationId) async {
    cancelCallCount++;
  }

  @override
  Future<void> cancelForObligation(String obligationId) async {}
}

class FakeReminderRepository implements ReminderRepository {
  bool applyCalled = false;
  bool shouldFailApply = false;
  int applyCallCount = 0;
  int markScheduledCallCount = 0;

  @override
  Future<void> applyReconciliationPlan(
      ReconciliationPlan plan, DateTime appliedAt) async {
    applyCallCount++;
    if (shouldFailApply) {
      throw Exception('Database failure');
    }
    applyCalled = true;
  }

  @override
  Future<void> markNotificationScheduled(
      {required String reminderId,
      required int localNotificationId,
      required DateTime scheduledAt}) async {
    markScheduledCallCount++;
  }

  @override
  Future<void> markNotificationFailed(
      {required String reminderId,
      required String errorCode,
      required DateTime attemptedAt}) async {}

  @override
  Future<void> insertIfAbsent(ReminderInstance reminder) async {}
  @override
  Future<void> insertBatchIfAbsent(List<ReminderInstance> reminders) async {}
  @override
  Future<ReminderInstance?> getById(String id) async => null;
  @override
  Future<ReminderInstance?> getByOccurrence(
          {required String scheduleRuleId,
          required String occurrenceKey}) async =>
      null;
  @override
  Future<List<ReminderInstance>> getForAgreement(String agreementId) async =>
      [];
  @override
  Future<List<ReminderInstance>> getForObligation(String obligationId) async =>
      [];
  @override
  Future<List<ReminderInstance>> getForScheduleRule(
          String scheduleRuleId) async =>
      [];
  @override
  Future<List<ReminderInstance>> getToday(DateTime now) async => [];
  @override
  Future<List<ReminderInstance>> getUpcoming(DateTime now) async => [];
  @override
  Future<void> transitionState(
      {required String reminderId,
      required ReminderState expectedCurrentState,
      required ReminderState targetState,
      required DateTime occurredAt}) async {}
  @override
  Future<void> supersedeFutureForRule(
      {required String scheduleRuleId,
      required int newGenerationVersion,
      required DateTime supersededAt}) async {}
  @override
  Future<void> cancelFutureForObligation(
      {required String obligationId, required DateTime cancelledAt}) async {}
}

void main() {
  group('ReminderReconciliationService', () {
    late FakeReminderRepository repository;
    late ReminderReconciliationPlanner planner;
    late FakeLocalNotificationAdapter adapter;
    late ReminderReconciliationService service;

    int inputsProvidedCount = 0;
    Completer<void>? inputsDelay;

    setUp(() {
      repository = FakeReminderRepository();
      planner = ReminderReconciliationPlanner();
      adapter = FakeLocalNotificationAdapter();
      inputsProvidedCount = 0;
      inputsDelay = null;

      service = ReminderReconciliationService(
        repository: repository,
        planner: planner,
        notificationAdapter: adapter,
        inputsProvider: () async {
          if (inputsDelay != null) {
            await inputsDelay!.future;
          }
          inputsProvidedCount++;
          return ReconciliationInputs(
            persistedReminders: [],
            candidateReminders: [],
            currentUtc: DateTime.now().toUtc(),
            windowStartUtc: DateTime.now().toUtc(),
            windowEndUtc: DateTime.now().toUtc().add(const Duration(days: 90)),
            fulfilledObligationIds: {},
            supersededScheduleRuleIds: {},
          );
        },
      );
    });

    test('one run at a time & overlapping calls coalesce', () async {
      inputsDelay = Completer<void>();

      // Trigger 1 (starts)
      final p1 = service.triggerReconciliation();

      // Trigger 2 and 3 (overlap, should coalesce into 1 follow-up)
      final p2 = service.triggerReconciliation();
      final p3 = service.triggerReconciliation();

      // They should return immediately with joinedExistingRun / rerunScheduled
      final r2 = await p2;
      final r3 = await p3;
      expect(r2.type, ReconciliationResultType.joinedExistingRun);
      expect(r3.type, ReconciliationResultType.joinedExistingRun);

      // Finish first run
      inputsDelay!.complete();

      final r1 = await p1;
      expect(r1.type, ReconciliationResultType.rerunScheduled);

      // The background follow-up run should happen
      // Wait for event loop to process the unawaited follow-up run
      await Future<void>.delayed(Duration.zero);

      expect(inputsProvidedCount,
          equals(2)); // Only 2 runs total, despite 3 triggers
      expect(repository.applyCallCount, equals(2));
    });

    test('lock releases after success', () async {
      final r1 = await service.triggerReconciliation();
      expect(r1.type, ReconciliationResultType.completed);

      final r2 = await service.triggerReconciliation();
      expect(r2.type, ReconciliationResultType.completed);

      expect(inputsProvidedCount, equals(2));
    });

    test('lock releases after failure', () async {
      repository.shouldFailApply = true;
      final r1 = await service.triggerReconciliation();
      expect(r1.type, ReconciliationResultType.failed);

      repository.shouldFailApply = false;
      final r2 = await service.triggerReconciliation();
      expect(r2.type, ReconciliationResultType.completed);

      expect(inputsProvidedCount, equals(2));
    });
  });
}
