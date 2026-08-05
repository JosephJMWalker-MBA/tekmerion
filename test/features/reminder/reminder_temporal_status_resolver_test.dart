import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_temporal_status_resolver.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_temporal_status.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  ReminderInstance createReminder({
    required DateTime dueAt,
    ReminderState state = ReminderState.scheduled,
    String timezone = 'UTC',
  }) {
    return ReminderInstance(
      id: 'test-id',
      agreementId: 'a1',
      obligationId: 'o1',
      scheduleRuleId: 'rule-id',
      occurrenceKey: 'key',
      dueAt: dueAt,
      remindAt: dueAt,
      timezone: timezone,
      state: state,
      notificationState: NotificationSchedulingState.pending,
      title: 'Test Reminder',
      body: 'Test Body',
      provenanceSummary: 'Test Provenance',
      generationVersion: 1,
      generatedAt: DateTime(2025).toUtc(),
      createdAt: DateTime(2025).toUtc(),
      updatedAt: DateTime(2025).toUtc(),
    );
  }

  group('ReminderTemporalStatusResolver', () {
    test('returns terminal for terminal states', () {
      final terminalStates = [
        ReminderState.completed,
        ReminderState.cancelled,
        ReminderState.dismissed,
        ReminderState.expired,
        ReminderState.superseded,
      ];

      for (final state in terminalStates) {
        final r =
            createReminder(dueAt: DateTime(2026, 1, 1).toUtc(), state: state);
        expect(
          ReminderTemporalStatusResolver.resolve(
            reminder: r,
            currentUtc: DateTime(2026, 1, 1).toUtc(),
            gracePeriod: const Duration(days: 1),
          ),
          equals(ReminderTemporalStatus.terminal),
        );
      }
    });

    test('returns acknowledged for acknowledged state', () {
      final r = createReminder(
          dueAt: DateTime(2026, 1, 1).toUtc(),
          state: ReminderState.acknowledged);
      expect(
        ReminderTemporalStatusResolver.resolve(
          reminder: r,
          currentUtc: DateTime(2026, 1, 1).toUtc(),
          gracePeriod: const Duration(days: 1),
        ),
        equals(ReminderTemporalStatus.acknowledged),
      );
    });

    test('returns overdue if current time is past dueAt + gracePeriod', () {
      final dueAt = DateTime.utc(2026, 8, 1, 10, 0); // Aug 1
      final r = createReminder(dueAt: dueAt);

      final currentUtc = DateTime.utc(2026, 8, 4, 10, 0); // Aug 4

      expect(
        ReminderTemporalStatusResolver.resolve(
          reminder: r,
          currentUtc: currentUtc,
          gracePeriod: const Duration(days: 2),
        ),
        equals(ReminderTemporalStatus.overdue),
      );
    });

    test('returns dueToday if it is due in the past but within grace period',
        () {
      final dueAt = DateTime.utc(2026, 8, 1, 10, 0); // Aug 1
      final r = createReminder(dueAt: dueAt);

      final currentUtc =
          DateTime.utc(2026, 8, 2, 10, 0); // Aug 2, not overdue yet

      expect(
        ReminderTemporalStatusResolver.resolve(
          reminder: r,
          currentUtc: currentUtc,
          gracePeriod: const Duration(days: 2),
        ),
        equals(ReminderTemporalStatus.dueToday),
      );
    });

    test('returns dueToday if local calendar days match', () {
      // dueAt UTC is Aug 2 03:00, which is Aug 1 23:00 in America/New_York
      final dueAt = DateTime.utc(2026, 8, 2, 3, 0);
      final r = createReminder(dueAt: dueAt, timezone: 'America/New_York');

      // currentUtc is Aug 1 12:00, which is Aug 1 08:00 in America/New_York
      final currentUtc = DateTime.utc(2026, 8, 1, 12, 0);

      expect(
        ReminderTemporalStatusResolver.resolve(
          reminder: r,
          currentUtc: currentUtc,
          gracePeriod: const Duration(days: 1),
        ),
        equals(ReminderTemporalStatus.dueToday),
      );
    });

    test('returns upcoming if local calendar days are in the future', () {
      final dueAt = DateTime.utc(2026, 8, 15, 10, 0);
      final r = createReminder(dueAt: dueAt);

      final currentUtc = DateTime.utc(2026, 8, 1, 10, 0);

      expect(
        ReminderTemporalStatusResolver.resolve(
          reminder: r,
          currentUtc: currentUtc,
          gracePeriod: const Duration(days: 1),
        ),
        equals(ReminderTemporalStatus.upcoming),
      );
    });
  });
}
