import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';

enum ReconciliationOperationType {
  insert,
  preserve,
  supersede,
  cancel,
  leaveHistoricalUnchanged,
}

enum ReconciliationReasonCode {
  candidateMissingFromPersistence,
  occurrenceIdentityMatched,
  obligationFulfilled,
  ruleSupersededAndOccurrenceFuture,
  terminalHistoryPreserved,
  occurrenceBeforeNowPreserved,
}

class ReconciliationOperation {

  const ReconciliationOperation({
    required this.reminder,
    required this.type,
    required this.reason,
    this.localNotificationId,
  });
  final ReminderInstance reminder;
  final ReconciliationOperationType type;
  final ReconciliationReasonCode reason;
  
  /// The local notification ID that should be used if scheduling this reminder, or
  /// null if it is not applicable (e.g. cancelled/superseded). For preserve and leaveHistoricalUnchanged,
  /// this should match the persisted id.
  final int? localNotificationId;
}

class ReconciliationPlan {

  const ReconciliationPlan(this.operations);
  final List<ReconciliationOperation> operations;

  Iterable<ReconciliationOperation> get inserts =>
      operations.where((op) => op.type == ReconciliationOperationType.insert);

  Iterable<ReconciliationOperation> get preserves =>
      operations.where((op) => op.type == ReconciliationOperationType.preserve);

  Iterable<ReconciliationOperation> get supersedes =>
      operations.where((op) => op.type == ReconciliationOperationType.supersede);

  Iterable<ReconciliationOperation> get cancels =>
      operations.where((op) => op.type == ReconciliationOperationType.cancel);

  Iterable<ReconciliationOperation> get historicalUnchanged =>
      operations.where((op) => op.type == ReconciliationOperationType.leaveHistoricalUnchanged);
}
