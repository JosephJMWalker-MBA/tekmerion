import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_temporal_status.dart';
import 'package:timezone/timezone.dart' as tz;

/// Pure presentation helper to determine a reminder's temporal status.
class ReminderTemporalStatusResolver {
  /// Resolves the temporal display status of a reminder.
  ///
  /// [reminder] The canonical reminder instance.
  /// [currentUtc] The current UTC instant (provided for testability and purity).
  /// [gracePeriod] The duration after dueAt before it is considered overdue.
  ///
  /// Note: "today" is evaluated in the context of the reminder's original timezone.
  static ReminderTemporalStatus resolve({
    required ReminderInstance reminder,
    required DateTime currentUtc,
    required Duration gracePeriod,
  }) {
    if (reminder.state.isTerminal) {
      return ReminderTemporalStatus.terminal;
    }

    if (reminder.state == ReminderState.acknowledged) {
      return ReminderTemporalStatus.acknowledged;
    }

    // It is in scheduled state. Check due/overdue.
    final dueUtc = reminder.dueAt;

    // Check if it's overdue
    if (currentUtc.isAfter(dueUtc.add(gracePeriod))) {
      return ReminderTemporalStatus.overdue;
    }

    // Check if due today in the reminder's timezone
    try {
      final location = tz.getLocation(reminder.timezone);
      final currentLocal = tz.TZDateTime.from(currentUtc, location);
      final dueLocal = tz.TZDateTime.from(dueUtc, location);

      if (currentLocal.year == dueLocal.year &&
          currentLocal.month == dueLocal.month &&
          currentLocal.day == dueLocal.day) {
        return ReminderTemporalStatus.dueToday;
      }

      // If it is due in the past but not overdue and not today,
      // it means it was due yesterday (or earlier) but within grace period.
      // We will still categorize it as dueToday or overdue.
      if (currentUtc.isAfter(dueUtc)) {
        return ReminderTemporalStatus.dueToday;
      }
    } catch (_) {
      // If timezone fails, fallback to UTC comparison
      if (currentUtc.year == dueUtc.year &&
          currentUtc.month == dueUtc.month &&
          currentUtc.day == dueUtc.day) {
        return ReminderTemporalStatus.dueToday;
      }
      if (currentUtc.isAfter(dueUtc)) {
        return ReminderTemporalStatus.dueToday;
      }
    }

    return ReminderTemporalStatus.upcoming;
  }
}
