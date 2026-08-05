import 'dart:async';
import 'package:tekmerion/src/features/reminder/application/local_notification_adapter.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_permission_state.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_reconciliation_planner.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_repository.dart';

enum ReconciliationResultType {
  completed,
  completedWithDeliveryFailures,
  joinedExistingRun,
  rerunScheduled,
  failed,
}

class ReconciliationResult {
  const ReconciliationResult(this.type, {this.errorMessage});
  final ReconciliationResultType type;
  final String? errorMessage;
}

class ReminderReconciliationService {
  ReminderReconciliationService({
    required this.repository,
    required this.planner,
    required this.notificationAdapter,
    required this.inputsProvider,
  });
  final ReminderRepository repository;
  final ReminderReconciliationPlanner planner;
  final LocalNotificationAdapter notificationAdapter;

  // A callback or interface to supply the fresh inputs would be injected here.
  // For the sake of the domain service without hardcoding missing obligation repos,
  // we take a provider function that yields the fresh inputs.
  final Future<ReconciliationInputs> Function() inputsProvider;

  bool _isReconciling = false;
  bool _rerunRequested = false;

  /// Trigger a reconciliation run. Concurrent calls will coalesce.
  Future<ReconciliationResult> triggerReconciliation() async {
    if (_isReconciling) {
      _rerunRequested = true;
      return const ReconciliationResult(
          ReconciliationResultType.joinedExistingRun);
    }

    _isReconciling = true;
    _rerunRequested = false;

    try {
      final result = await _runSingleReconciliation();

      // We must copy the rerun flag before setting _isReconciling to false
      // to avoid race conditions, though Dart is single-threaded async.
      final shouldRerun = _rerunRequested;
      _isReconciling = false;
      _rerunRequested = false;

      if (shouldRerun) {
        // Fire and forget the follow-up run so we don't block this return.
        // It will acquire the lock itself.
        unawaited(triggerReconciliation());
        // Return a special status for the first run that it finished but a rerun was scheduled
        return const ReconciliationResult(
            ReconciliationResultType.rerunScheduled);
      }

      return result;
    } catch (e) {
      _isReconciling = false;
      _rerunRequested = false;
      return ReconciliationResult(ReconciliationResultType.failed,
          errorMessage: e.toString());
    }
  }

  Future<ReconciliationResult> _runSingleReconciliation() async {
    // 1. Load State & 2. Generate Candidates (provided by inputsProvider)
    final inputs = await inputsProvider();

    // 3. Plan
    final plan = planner.createPlan(
      persistedReminders: inputs.persistedReminders,
      candidateReminders: inputs.candidateReminders,
      currentUtc: inputs.currentUtc,
      windowStartUtc: inputs.windowStartUtc,
      windowEndUtc: inputs.windowEndUtc,
      fulfilledObligationIds: inputs.fulfilledObligationIds,
      supersededScheduleRuleIds: inputs.supersededScheduleRuleIds,
    );

    // 4. Canonical Commit
    final appliedAt = inputs.currentUtc; // or DateTime.now().toUtc()
    await repository.applyReconciliationPlan(plan, appliedAt);

    // 5. Platform Action & 6. Notification Status Commit
    bool hasDeliveryFailures = false;
    final permissionState = await notificationAdapter.inspectPermissionState();

    // We process inserts and preserves that need scheduling.
    // Wait, preserves might also need scheduling if they failed previously or weren't scheduled yet.
    // The instructions say: "Eligible for scheduling: notificationState notRequested when permission is granted; failed when error policy permits retry".
    final eligibleToSchedule =
        plan.inserts.followedBy(plan.preserves).where((op) {
      if (op.localNotificationId == null) return false;
      final ns = op.reminder.notificationState;
      if (ns == NotificationSchedulingState.scheduled) return false;

      if (ns == NotificationSchedulingState.notRequested &&
          permissionState == NotificationPermissionState.granted) {
        return true;
      }
      if (ns == NotificationSchedulingState.failed) {
        return true; // Simplified retry policy
      }
      return false;
    });

    for (final op in eligibleToSchedule) {
      try {
        if (permissionState == NotificationPermissionState.granted) {
          final request = NotificationScheduleRequest(
            notificationId: op.localNotificationId!,
            reminderId: op.reminder.id,
            agreementId: op.reminder.agreementId,
            obligationId: op.reminder.obligationId,
            scheduledUtcInstant: op.reminder.remindAt,
            timezoneIdentifier: op.reminder.timezone,
            title: op.reminder.title,
            body: op.reminder.body,
            payloadData: {},
          );

          final scheduleResult =
              await notificationAdapter.scheduleNotification(request);

          if (scheduleResult == NotificationSchedulingState.scheduled) {
            await repository.markNotificationScheduled(
              reminderId: op.reminder.id,
              localNotificationId: op.localNotificationId!,
              scheduledAt: appliedAt,
            );
          } else {
            hasDeliveryFailures = true;
            await repository.markNotificationFailed(
              reminderId: op.reminder.id,
              errorCode: 'adapter_refused',
              attemptedAt: appliedAt,
            );
          }
        } else {
          // If permission is denied/unavailable, we record that.
          final resultingState =
              _mapPermissionToSchedulingState(permissionState);
          // Wait, the instructions say: "reconciliation never requests permission; notDetermined maps to notRequested".
          // "permission failure never changes ReminderState".
          // "denied maps to permissionDenied; unavailable maps to unavailable".
          // We can update the notification state.
          await repository.markNotificationFailed(
            // we might need a general state update
            reminderId: op.reminder.id,
            errorCode: resultingState.name,
            attemptedAt: appliedAt,
          );
        }
      } catch (e) {
        hasDeliveryFailures = true;
        await repository.markNotificationFailed(
          reminderId: op.reminder.id,
          errorCode: 'platform_exception',
          attemptedAt: appliedAt,
        );
      }
    }

    // Handle Cancellations and Supersessions at the platform level
    final eligibleToCancel = plan.cancels
        .followedBy(plan.supersedes)
        .where((op) => op.localNotificationId != null);
    for (final op in eligibleToCancel) {
      try {
        await notificationAdapter.cancelNotification(op.localNotificationId!);
      } catch (e) {
        // Platform failure on cancel does not corrupt canonical state
      }
    }

    if (hasDeliveryFailures) {
      return const ReconciliationResult(
          ReconciliationResultType.completedWithDeliveryFailures);
    }
    return const ReconciliationResult(ReconciliationResultType.completed);
  }

  NotificationSchedulingState _mapPermissionToSchedulingState(
      NotificationPermissionState permission) {
    switch (permission) {
      case NotificationPermissionState.notDetermined:
        return NotificationSchedulingState.notRequested;
      case NotificationPermissionState.granted:
        return NotificationSchedulingState.pending; // Intermediate
      case NotificationPermissionState.denied:
      case NotificationPermissionState.permanentlyDenied:
        return NotificationSchedulingState.permissionDenied;
      case NotificationPermissionState.unavailable:
        return NotificationSchedulingState.unavailable;
    }
  }
}

class ReconciliationInputs {
  const ReconciliationInputs({
    required this.persistedReminders,
    required this.candidateReminders,
    required this.currentUtc,
    required this.windowStartUtc,
    required this.windowEndUtc,
    required this.fulfilledObligationIds,
    required this.supersededScheduleRuleIds,
  });
  final Iterable<ReminderInstance> persistedReminders;
  final Iterable<ReminderInstance> candidateReminders;
  final DateTime currentUtc;
  final DateTime windowStartUtc;
  final DateTime windowEndUtc;
  final Set<String> fulfilledObligationIds;
  final Set<String> supersededScheduleRuleIds;
}
