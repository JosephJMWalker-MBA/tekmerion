import 'package:meta/meta.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';

@immutable
class ReminderInstance {
  const ReminderInstance({
    required this.id,
    required this.agreementId,
    required this.obligationId,
    required this.scheduleRuleId,
    required this.occurrenceKey,
    required this.dueAt,
    required this.remindAt,
    required this.timezone,
    required this.state,
    required this.generationVersion,
    required this.generatedAt,
    this.acknowledgedAt,
    this.dismissedAt,
    this.completedAt,
    this.cancelledAt,
    this.supersededAt,
    this.expiredAt,
    this.localNotificationId,
    required this.notificationState,
    this.notificationAttemptedAt,
    this.notificationScheduledAt,
    this.notificationErrorCode,
    required this.title,
    required this.body,
    required this.provenanceSummary,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String agreementId;
  final String obligationId;
  final String scheduleRuleId;
  final String occurrenceKey;

  /// The strict UTC instant when the obligation is due.
  final DateTime dueAt;

  /// The strict UTC instant when the reminder should notify the user.
  final DateTime remindAt;

  /// The authoritative timezone string from the ScheduleRule.
  final String timezone;

  final ReminderState state;
  final int generationVersion;
  final DateTime generatedAt;
  final DateTime? acknowledgedAt;
  final DateTime? dismissedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? supersededAt;
  final DateTime? expiredAt;
  final int? localNotificationId;
  final NotificationSchedulingState notificationState;
  final DateTime? notificationAttemptedAt;
  final DateTime? notificationScheduledAt;
  final String? notificationErrorCode;
  final String title;
  final String body;
  final String provenanceSummary;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReminderInstance copyWith({
    String? id,
    String? agreementId,
    String? obligationId,
    String? scheduleRuleId,
    String? occurrenceKey,
    DateTime? dueAt,
    DateTime? remindAt,
    String? timezone,
    ReminderState? state,
    int? generationVersion,
    DateTime? generatedAt,
    DateTime? acknowledgedAt,
    DateTime? dismissedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? supersededAt,
    DateTime? expiredAt,
    int? localNotificationId,
    NotificationSchedulingState? notificationState,
    DateTime? notificationAttemptedAt,
    DateTime? notificationScheduledAt,
    String? notificationErrorCode,
    String? title,
    String? body,
    String? provenanceSummary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderInstance(
      id: id ?? this.id,
      agreementId: agreementId ?? this.agreementId,
      obligationId: obligationId ?? this.obligationId,
      scheduleRuleId: scheduleRuleId ?? this.scheduleRuleId,
      occurrenceKey: occurrenceKey ?? this.occurrenceKey,
      dueAt: dueAt ?? this.dueAt,
      remindAt: remindAt ?? this.remindAt,
      timezone: timezone ?? this.timezone,
      state: state ?? this.state,
      generationVersion: generationVersion ?? this.generationVersion,
      generatedAt: generatedAt ?? this.generatedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      supersededAt: supersededAt ?? this.supersededAt,
      expiredAt: expiredAt ?? this.expiredAt,
      localNotificationId: localNotificationId ?? this.localNotificationId,
      notificationState: notificationState ?? this.notificationState,
      notificationAttemptedAt:
          notificationAttemptedAt ?? this.notificationAttemptedAt,
      notificationScheduledAt:
          notificationScheduledAt ?? this.notificationScheduledAt,
      notificationErrorCode:
          notificationErrorCode ?? this.notificationErrorCode,
      title: title ?? this.title,
      body: body ?? this.body,
      provenanceSummary: provenanceSummary ?? this.provenanceSummary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderInstance &&
        other.id == id &&
        other.agreementId == agreementId &&
        other.obligationId == obligationId &&
        other.scheduleRuleId == scheduleRuleId &&
        other.occurrenceKey == occurrenceKey &&
        other.dueAt == dueAt &&
        other.remindAt == remindAt &&
        other.timezone == timezone &&
        other.state == state &&
        other.generationVersion == generationVersion &&
        other.generatedAt == generatedAt &&
        other.acknowledgedAt == acknowledgedAt &&
        other.dismissedAt == dismissedAt &&
        other.completedAt == completedAt &&
        other.cancelledAt == cancelledAt &&
        other.supersededAt == supersededAt &&
        other.expiredAt == expiredAt &&
        other.localNotificationId == localNotificationId &&
        other.notificationState == notificationState &&
        other.notificationAttemptedAt == notificationAttemptedAt &&
        other.notificationScheduledAt == notificationScheduledAt &&
        other.notificationErrorCode == notificationErrorCode &&
        other.title == title &&
        other.body == body &&
        other.provenanceSummary == provenanceSummary &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      agreementId,
      obligationId,
      scheduleRuleId,
      occurrenceKey,
      dueAt,
      remindAt,
      timezone,
      state,
      generationVersion,
      generatedAt,
      acknowledgedAt,
      dismissedAt,
      completedAt,
      cancelledAt,
      supersededAt,
      expiredAt,
      localNotificationId,
      notificationState,
      notificationAttemptedAt,
      notificationScheduledAt,
      notificationErrorCode,
      title,
      body,
      provenanceSummary,
      createdAt,
      updatedAt,
    ]);
  }
}
