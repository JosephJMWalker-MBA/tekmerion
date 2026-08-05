/// Pure presentation temporal status of a reminder, derived dynamically from UTC current time.
enum ReminderTemporalStatus {
  /// The reminder is due in the future.
  upcoming,

  /// The reminder is due today (in the context of the user's current calendar day in the reminder's timezone).
  dueToday,

  /// The reminder is overdue (dueAt + grace period is in the past).
  overdue,

  /// The reminder has been acknowledged by the user.
  acknowledged,

  /// The reminder is in a terminal state (completed, cancelled, dismissed, superseded, expired).
  terminal,
}
