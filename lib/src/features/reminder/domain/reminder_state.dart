/// Defines the logical workflow state of a reminder instance.
/// Notification delivery state is tracked separately.
enum ReminderState {
  /// Active state. The reminder is scheduled for a future time.
  /// Note: 'due' is no longer a persisted state, it is derived dynamically via (due_at <= now).
  scheduled,

  /// Intermediate state. User has acknowledged but not yet resolved the reminder.
  acknowledged,

  /// Terminal state. User dismissed the reminder without completing the obligation.
  dismissed,

  /// Terminal state. The obligation was completed.
  completed,

  /// Terminal state. The reminder was manually cancelled by the user.
  cancelled,

  /// Terminal state. The reminder's schedule rule was updated, superseding this instance.
  superseded,

  /// Terminal state. The reminder window expired without action.
  expired,
}
