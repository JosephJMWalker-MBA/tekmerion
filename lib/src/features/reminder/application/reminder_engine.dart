import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:tekmerion/src/features/obligation/domain/schedule_rule.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';

import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';
import 'package:timezone/timezone.dart' as tz;

class ReminderEngine {
  /// Generates a deterministic list of [ReminderInstance] candidates for a given [ScheduleRule].
  ///
  /// [rule] The user-confirmed ScheduleRule.
  /// [agreementId] The agreement this rule applies to.
  /// [windowStart] The beginning of the evaluation window (UTC).
  /// [windowEnd] The end of the evaluation window (UTC).
  /// [now] The current clock time (UTC), used to mark `generatedAt`.
  /// [generationVersion] The current generation pass, factored into the occurrence key.
  static List<ReminderInstance> generateCandidates({
    required ScheduleRule rule,
    required String agreementId,
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime now,
    required int generationVersion,
  }) {
    // 1. Resolve timezone
    tz.Location location;
    if (rule.timezone == 'UTC') {
      location = tz.UTC;
    } else {
      location = tz.getLocation(rule.timezone);
    }

    // 2. Identify the generator
    if (rule.ruleType == ScheduleRuleType.manualOnly) {
      return [];
    }

    final occurrences = <DateTime>[];

    // Localize the start time. Note that if startAt is a strict UTC instant,
    // TZDateTime.from() correctly places it in the target location's local time.
    // However, the test suite says "Local time expressed as UTC component by the app",
    // meaning the components (year, month, day, hour, minute) of startAt represent local time.
    final localStart = tz.TZDateTime(
        location,
        rule.startAt.year,
        rule.startAt.month,
        rule.startAt.day,
        rule.startAt.hour,
        rule.startAt.minute,
        rule.startAt.second);

    if (rule.ruleType == ScheduleRuleType.oneTime) {
      occurrences.add(localStart);
    } else if (rule.ruleType == ScheduleRuleType.monthlyDayOfMonth) {
      var current = localStart;
      while (
          current.isBefore(windowEnd) || current.isAtSameMomentAs(windowEnd)) {
        if (rule.endAt != null && current.isAfter(rule.endAt!)) {
          break;
        }
        occurrences.add(current);

        int nextYear = current.year;
        int nextMonth = current.month + 1;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear += 1;
        }

        int nextDay = localStart.day;
        final daysInNextMonth = _daysInMonth(nextYear, nextMonth);
        if (nextDay > daysInNextMonth) {
          nextDay = daysInNextMonth;
        }

        current = tz.TZDateTime(location, nextYear, nextMonth, nextDay,
            localStart.hour, localStart.minute, localStart.second);
      }
    } else if (rule.ruleType == ScheduleRuleType.intervalDays) {
      final intervalDays = int.tryParse(rule.recurrenceExpression ?? '1') ?? 1;
      var current = localStart;
      while (
          current.isBefore(windowEnd) || current.isAtSameMomentAs(windowEnd)) {
        if (rule.endAt != null && current.isAfter(rule.endAt!)) {
          break;
        }
        occurrences.add(current);
        current = current.add(Duration(days: intervalDays));
      }
    } else {
      throw UnsupportedError('Unsupported ScheduleRuleType: ${rule.ruleType}');
    }

    // 3. Filter and map to instances
    final candidates = <ReminderInstance>[];
    for (final occLocal in occurrences) {
      // Ensure we get a standard core DateTime in UTC, not a TZDateTime.
      final occUtc = DateTime.fromMillisecondsSinceEpoch(
          occLocal.millisecondsSinceEpoch,
          isUtc: true);

      if (occUtc.isBefore(windowStart)) {
        continue;
      }

      final remindAtUtc =
          occUtc.subtract(Duration(seconds: rule.leadTimeSeconds));
      final occurrenceKey =
          _generateOccurrenceKey(rule.id, occUtc, generationVersion);

      candidates.add(
        ReminderInstance(
          id: 'rem_${occurrenceKey.substring(0, 16)}',
          agreementId: agreementId,
          obligationId: rule.obligationId,
          scheduleRuleId: rule.id,
          occurrenceKey: occurrenceKey,
          dueAt: occUtc,
          remindAt: remindAtUtc,
          timezone: rule.timezone,
          state: ReminderState.scheduled,
          generationVersion: generationVersion,
          generatedAt: now,
          notificationState: NotificationSchedulingState.notRequested,
          title: 'Upcoming Obligation',
          body: 'An obligation is due at ${occUtc.toIso8601String()}',
          provenanceSummary:
              'Generated from rule ${rule.id} (version $generationVersion)',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return candidates;
  }

  static String _generateOccurrenceKey(
      String scheduleRuleId, DateTime dueAtUtc, int generationVersion) {
    final payload =
        '$scheduleRuleId|${dueAtUtc.toIso8601String()}|$generationVersion';
    final bytes = utf8.encode(payload);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static int _daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }
}
