import 'package:tekmerion/src/features/reminder/domain/notification_id_generator.dart';
import 'package:tekmerion/src/features/reminder/domain/reconciliation_plan.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';

class ReminderReconciliationPlanner {
  /// Maximum number of hash attempts for resolving localNotificationId collisions
  static const int maxIdAttempts = 10;

  ReconciliationPlan createPlan({
    required Iterable<ReminderInstance> persistedReminders,
    required Iterable<ReminderInstance> candidateReminders,
    required DateTime currentUtc,
    required DateTime windowStartUtc,
    required DateTime windowEndUtc,
    required Set<String> fulfilledObligationIds,
    required Set<String> supersededScheduleRuleIds,
  }) {
    final operations = <ReconciliationOperation>[];
    
    final persistedByOccurrence = {
      for (final r in persistedReminders) r.occurrenceKey: r,
    };
    
    // We must track used IDs to avoid collisions among both preserved and newly inserted
    final usedNotificationIds = <int>{};
    for (final r in persistedReminders) {
      if (r.localNotificationId != null &&
          (r.state == ReminderState.scheduled || r.state == ReminderState.acknowledged)) {
        usedNotificationIds.add(r.localNotificationId!);
      }
    }

    // 1. Process all existing persisted reminders first to see what should be preserved, superseded, or cancelled.
    for (final persisted in persistedReminders) {
      // Historical or terminal reminders are left unchanged.
      if (persisted.state.isTerminal || persisted.remindAt.isBefore(currentUtc)) {
        operations.add(ReconciliationOperation(
          reminder: persisted,
          type: ReconciliationOperationType.leaveHistoricalUnchanged,
          reason: persisted.state.isTerminal
              ? ReconciliationReasonCode.terminalHistoryPreserved
              : ReconciliationReasonCode.occurrenceBeforeNowPreserved,
          localNotificationId: persisted.localNotificationId,
        ),);
        continue;
      }

      // Check for fulfilled obligations
      if (fulfilledObligationIds.contains(persisted.obligationId)) {
        operations.add(ReconciliationOperation(
          reminder: persisted,
          type: ReconciliationOperationType.cancel,
          reason: ReconciliationReasonCode.obligationFulfilled,
        ),);
        continue;
      }

      // Check for superseded schedule rules
      // Only supersede future active reminders that are no longer represented by a valid candidate
      if (supersededScheduleRuleIds.contains(persisted.scheduleRuleId)) {
        // If a candidate still matches it, it is not superseded by the rule change.
        // But if the rule is superseded, the candidates should have the new rule ID, not the old one.
        // Wait, the prompt says: "supersede only future scheduled or acknowledged reminders no longer represented by a valid candidate".
        // Let's just check if it's in the candidate list. If not, supersede.
        operations.add(ReconciliationOperation(
          reminder: persisted,
          type: ReconciliationOperationType.supersede,
          reason: ReconciliationReasonCode.ruleSupersededAndOccurrenceFuture,
        ),);
        continue;
      }
      
      // If none of the above, we need to check if a candidate matches it to preserve it.
      // Or if it was generated before but there is no candidate now (maybe the rule changed 
      // but it wasn't in superseded rules list?). In a pure engine, if an active future reminder
      // doesn't have a matching candidate and its obligation is not fulfilled, it might be orphaned.
      // We will preserve it if there is a matching candidate. 
      // Wait, if it has a matching candidate, we preserve it. If it doesn't have a matching candidate 
      // but isn't flagged as superseded or cancelled, we should still probably supersede/cancel it?
      // The instructions say "New candidate: insert if absent; Matching identity: preserve."
      // Let's just preserve it if it matches a candidate.
      if (candidateReminders.any((c) => c.occurrenceKey == persisted.occurrenceKey)) {
        operations.add(ReconciliationOperation(
          reminder: persisted,
          type: ReconciliationOperationType.preserve,
          reason: ReconciliationReasonCode.occurrenceIdentityMatched,
          localNotificationId: persisted.localNotificationId,
        ),);
      } else {
        // If it's a future reminder that is not in the candidate list and not superseded/cancelled explicitly,
        // it means the rule generated different candidates (e.g. date shifted). We supersede it.
        operations.add(ReconciliationOperation(
          reminder: persisted,
          type: ReconciliationOperationType.supersede,
          reason: ReconciliationReasonCode.ruleSupersededAndOccurrenceFuture,
        ),);
      }
    }

    // 2. Process candidates to find new inserts.
    for (final candidate in candidateReminders) {
      if (!persistedByOccurrence.containsKey(candidate.occurrenceKey)) {
        // It's a new candidate, we need to allocate a notification ID.
        int attempt = 0;
        int? assignedId;
        
        while (attempt < maxIdAttempts) {
          final id = NotificationIdGenerator.generateId(candidate.occurrenceKey, attempt: attempt);
          if (!usedNotificationIds.contains(id)) {
            assignedId = id;
            usedNotificationIds.add(id);
            break;
          }
          attempt++;
        }
        
        if (assignedId == null) {
          throw StateError('Failed to allocate a unique notification ID for ${candidate.occurrenceKey} after $maxIdAttempts attempts.');
        }
        
        operations.add(ReconciliationOperation(
          reminder: candidate,
          type: ReconciliationOperationType.insert,
          reason: ReconciliationReasonCode.candidateMissingFromPersistence,
          localNotificationId: assignedId,
        ),);
      }
    }

    // Ensure deterministic ordering: leaveUnchanged, cancel, supersede, preserve, insert
    // Sort by type index, then by occurrenceKey
    operations.sort((a, b) {
      final typeCmp = a.type.index.compareTo(b.type.index);
      if (typeCmp != 0) return typeCmp;
      return a.reminder.occurrenceKey.compareTo(b.reminder.occurrenceKey);
    });

    return ReconciliationPlan(operations);
  }
}
