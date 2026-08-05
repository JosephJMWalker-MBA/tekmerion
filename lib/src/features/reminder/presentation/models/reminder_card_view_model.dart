import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_temporal_status.dart';

/// Presentation layer model for a reminder card.
/// Combines the canonical ReminderInstance with joined agreement and obligation facts,
/// and purely derived presentation state.
class ReminderCardViewModel {
  const ReminderCardViewModel({
    required this.reminderId,
    required this.agreementId,
    required this.agreementTitle,
    required this.obligationId,
    required this.obligationTitle,
    this.clauseReference,
    required this.dueAtUtc,
    required this.timezone,
    required this.dueAtDisplay,
    required this.reminderState,
    required this.temporalStatus,
    required this.notificationStatus,
    required this.canAcknowledge,
    required this.canDismiss,
    required this.canComplete,
  });
  final String reminderId;
  final String agreementId;
  final String agreementTitle;
  final String obligationId;
  final String obligationTitle;
  final String? clauseReference;

  final DateTime dueAtUtc;
  final String timezone;
  final String dueAtDisplay;

  final ReminderState reminderState;
  final ReminderTemporalStatus temporalStatus;
  final NotificationSchedulingState notificationStatus;

  final bool canAcknowledge;
  final bool canDismiss;
  final bool canComplete;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderCardViewModel &&
        other.reminderId == reminderId &&
        other.agreementId == agreementId &&
        other.agreementTitle == agreementTitle &&
        other.obligationId == obligationId &&
        other.obligationTitle == obligationTitle &&
        other.clauseReference == clauseReference &&
        other.dueAtUtc == dueAtUtc &&
        other.timezone == timezone &&
        other.dueAtDisplay == dueAtDisplay &&
        other.reminderState == reminderState &&
        other.temporalStatus == temporalStatus &&
        other.notificationStatus == notificationStatus &&
        other.canAcknowledge == canAcknowledge &&
        other.canDismiss == canDismiss &&
        other.canComplete == canComplete;
  }

  @override
  int get hashCode {
    return Object.hash(
      reminderId,
      agreementId,
      agreementTitle,
      obligationId,
      obligationTitle,
      clauseReference,
      dueAtUtc,
      timezone,
      dueAtDisplay,
      reminderState,
      temporalStatus,
      notificationStatus,
      canAcknowledge,
      canDismiss,
      canComplete,
    );
  }
}
