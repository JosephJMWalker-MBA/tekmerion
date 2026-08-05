import 'package:tekmerion/src/features/reminder/domain/reconciliation_plan.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';

abstract class ReminderRepository {
  /// Inserts the reminder if it does not already exist by unique occurrence constraint.
  Future<void> insertIfAbsent(ReminderInstance reminder);

  /// Batch inserts reminders, ignoring conflicts on unique occurrence constraints.
  Future<void> insertBatchIfAbsent(List<ReminderInstance> reminders);

  /// Retrieves a reminder by its primary key ID.
  Future<ReminderInstance?> getById(String id);

  /// Retrieves a reminder by its unique schedule rule ID and occurrence key.
  Future<ReminderInstance?> getByOccurrence({
    required String scheduleRuleId,
    required String occurrenceKey,
  });

  /// Retrieves all reminders for an agreement.
  Future<List<ReminderInstance>> getForAgreement(String agreementId);

  /// Retrieves all reminders for an obligation.
  Future<List<ReminderInstance>> getForObligation(String obligationId);

  /// Retrieves all reminders for a schedule rule.
  Future<List<ReminderInstance>> getForScheduleRule(String scheduleRuleId);

  /// Retrieves all reminders due today or before, sorted appropriately.
  Future<List<ReminderInstance>> getToday(DateTime now);

  /// Retrieves future scheduled reminders.
  Future<List<ReminderInstance>> getUpcoming(DateTime now);

  /// Transitions a reminder to a new state if it matches the expected current state.
  /// Writes the appropriate terminal timestamp atomically.
  Future<void> transitionState({
    required String reminderId,
    required ReminderState expectedCurrentState,
    required ReminderState targetState,
    required DateTime occurredAt,
  });

  /// Updates notification scheduling state to scheduled.
  Future<void> markNotificationScheduled({
    required String reminderId,
    required int localNotificationId,
    required DateTime scheduledAt,
  });

  /// Updates notification scheduling state to failed.
  Future<void> markNotificationFailed({
    required String reminderId,
    required String errorCode,
    required DateTime attemptedAt,
  });

  /// Supersedes active future reminders for a given rule if they match an old generation version.
  Future<void> supersedeFutureForRule({
    required String scheduleRuleId,
    required int newGenerationVersion,
    required DateTime supersededAt,
  });

  /// Cancels active future reminders when an obligation is fulfilled.
  Future<void> cancelFutureForObligation({
    required String obligationId,
    required DateTime cancelledAt,
  });

  /// Atomically applies a reconciliation plan.
  Future<void> applyReconciliationPlan(ReconciliationPlan plan, DateTime appliedAt);
}
