import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/obligation/domain/schedule_rule.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_engine.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('ReminderEngine Deterministic Generation', () {
    final now = DateTime.utc(2026, 1, 1);
    final windowStart = DateTime.utc(2026, 1, 1);
    final windowEnd = DateTime.utc(2027, 1, 1);

    test('1. one-time rule generates one reminder', () {
      final rule = ScheduleRule(
        id: 'rule_1',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.oneTime,
        timezone: 'UTC',
        startAt: DateTime.utc(2026, 2, 1, 9, 0),
        leadTimeSeconds: 3600,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      expect(candidates.length, 1);
      expect(candidates.first.dueAt, DateTime.utc(2026, 2, 1, 9, 0));
    });

    test('2. identical rerun generates same occurrence key', () {
      final rule = ScheduleRule(
        id: 'rule_2',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.oneTime,
        timezone: 'UTC',
        startAt: DateTime.utc(2026, 2, 1, 9, 0),
        leadTimeSeconds: 3600,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates1 = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );
      final candidates2 = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      expect(candidates1.first.occurrenceKey, candidates2.first.occurrenceKey);
    });

    test('4. lead time calculation applies correctly to remindAt', () {
      final rule = ScheduleRule(
        id: 'rule_4',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.oneTime,
        timezone: 'UTC',
        startAt: DateTime.utc(2026, 2, 1, 9, 0),
        leadTimeSeconds: 3600, // 1 hour
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      expect(candidates.first.remindAt, DateTime.utc(2026, 2, 1, 8, 0));
    });

    test('5. grace-period calculation explicitly doesnt rewrite dueAt', () {
      final rule = ScheduleRule(
        id: 'rule_5',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.oneTime,
        timezone: 'UTC',
        startAt: DateTime.utc(2026, 2, 1, 9, 0),
        leadTimeSeconds: 0,
        gracePeriodSeconds: 86400, // 1 day
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      expect(candidates.first.dueAt, DateTime.utc(2026, 2, 1, 9, 0));
    });

    test('6. dueAt and remindAt are strict UTC instants', () {
      final rule = ScheduleRule(
        id: 'rule_6',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.oneTime,
        timezone: 'America/New_York', // EST
        startAt: DateTime.utc(2026, 2, 1, 9,
            0,), // Local time expressed as UTC component by the app
        leadTimeSeconds: 0,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      expect(candidates.first.dueAt.isUtc, isTrue);
      expect(candidates.first.remindAt.isUtc, isTrue);
      // 9:00 AM NY time in Feb is UTC-5, so 14:00 UTC.
      expect(candidates.first.dueAt, DateTime.utc(2026, 2, 1, 14, 0));
    });

    test('7. original timezone string is preserved in candidate', () {
      final rule = ScheduleRule(
        id: 'rule_7',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.oneTime,
        timezone: 'America/New_York',
        startAt: DateTime.utc(2026, 2, 1, 9, 0),
        leadTimeSeconds: 0,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      expect(candidates.first.timezone, 'America/New_York');
    });

    test(
        '8. daylight-saving spring transition (non-existent time fast-forwards)',
        () {
      // In 2026, US Spring Forward is March 8. 2:00 AM -> 3:00 AM.
      final rule = ScheduleRule(
        id: 'rule_8',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.oneTime,
        timezone: 'America/New_York',
        startAt: DateTime.utc(2026, 3, 8, 2, 30), // 2:30 AM is skipped
        leadTimeSeconds: 0,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      // TZ package handles it by rolling forward. 3:30 AM local -> EDT is UTC-4 -> 7:30 UTC
      expect(candidates.first.dueAt, DateTime.utc(2026, 3, 8, 7, 30));
    });

    test(
        '9. daylight-saving fall transition (ambiguous time selects first occurrence)',
        () {
      // In 2026, US Fall Back is Nov 1. 1:00 AM to 2:00 AM repeats.
      final rule = ScheduleRule(
        id: 'rule_9',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.oneTime,
        timezone: 'America/New_York',
        startAt: DateTime.utc(2026, 11, 1, 1, 30),
        leadTimeSeconds: 0,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      // It should pick the EDT occurrence first (UTC-4) -> 5:30 UTC
      expect(candidates.first.dueAt, DateTime.utc(2026, 11, 1, 5, 30));
    });

    test('10. monthly recurrence day clamping (leap years, month-end)', () {
      final rule = ScheduleRule(
        id: 'rule_10',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.monthlyDayOfMonth,
        timezone: 'UTC',
        startAt: DateTime.utc(2024, 1, 31, 9, 0), // Leap year 2024
        endAt: DateTime.utc(2024, 4, 15, 9, 0), // Generate just a few months
        leadTimeSeconds: 0,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: DateTime.utc(2024, 1, 1),
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      expect(candidates.length, 3);
      expect(candidates[0].dueAt, DateTime.utc(2024, 1, 31, 9, 0));
      expect(candidates[1].dueAt,
          DateTime.utc(2024, 2, 29, 9, 0),); // Leap year clamp
      expect(candidates[2].dueAt, DateTime.utc(2024, 3, 31, 9, 0));
    });

    test('11. intervalDays recurrence generates strict sequences', () {
      final rule = ScheduleRule(
        id: 'rule_11',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.intervalDays,
        timezone: 'UTC',
        startAt: DateTime.utc(2026, 1, 1, 9, 0),
        endAt: DateTime.utc(2026, 1, 20, 9, 0),
        recurrenceExpression: '7', // Every 7 days
        leadTimeSeconds: 0,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      expect(candidates.length, 3);
      expect(candidates[0].dueAt, DateTime.utc(2026, 1, 1, 9, 0));
      expect(candidates[1].dueAt, DateTime.utc(2026, 1, 8, 9, 0));
      expect(candidates[2].dueAt, DateTime.utc(2026, 1, 15, 9, 0));
    });

    test('12. manualOnly rule generates zero reminders', () {
      final rule = ScheduleRule(
        id: 'rule_12',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.manualOnly,
        timezone: 'UTC',
        startAt: DateTime.utc(2026, 1, 1, 9, 0),
        leadTimeSeconds: 0,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      expect(candidates.isEmpty, isTrue);
    });

    test('13. bounded generation window respects windowStart and windowEnd',
        () {
      final rule = ScheduleRule(
        id: 'rule_13',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.intervalDays,
        timezone: 'UTC',
        startAt: DateTime.utc(2026, 1, 1, 9, 0),
        recurrenceExpression: '1', // Every day
        leadTimeSeconds: 0,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: DateTime.utc(2026, 1, 5, 0, 0),
        windowEnd: DateTime.utc(2026, 1, 10, 23, 59),
        now: now,
        generationVersion: 1,
      );

      expect(candidates.length, 6);
      expect(candidates.first.dueAt, DateTime.utc(2026, 1, 5, 9, 0));
      expect(candidates.last.dueAt, DateTime.utc(2026, 1, 10, 9, 0));
    });

    test(
        '14. fulfilled obligation generates no future reminder (simulated outside pure engine by passing no rule, or end date clamped)',
        () {
      // In the pure engine, a fulfilled obligation means we pass windowEnd = fulfilledAt or endAt = fulfilledAt.
      final rule = ScheduleRule(
        id: 'rule_14',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.intervalDays,
        timezone: 'UTC',
        startAt: DateTime.utc(2026, 1, 1, 9, 0),
        endAt: DateTime.utc(2026, 1, 3, 9, 0), // Fulfilled/Cancelled here
        recurrenceExpression: '1',
        leadTimeSeconds: 0,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );

      expect(candidates.length, 3); // 1st, 2nd, 3rd only
    });
    test(
        'occurrence identity is deterministic and unique by generation version',
        () {
      final now = DateTime.now().toUtc();
      final windowStart = now.subtract(const Duration(days: 30));
      final windowEnd = now.add(const Duration(days: 30));

      final rule = ScheduleRule(
        id: 'rule_identity',
        obligationId: 'ob_1',
        ruleType: ScheduleRuleType.oneTime,
        timezone: 'UTC',
        startAt: now,
        leadTimeSeconds: 3600,
        gracePeriodSeconds: 0,
        confirmedAt: now,
      );

      final candidates1 = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 1,
      );
      final candidates2 = ReminderEngine.generateCandidates(
        rule: rule,
        agreementId: 'ag_1',
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
        generationVersion: 2,
      );

      final c1 = candidates1.first;
      final c2 = candidates2.first;

      expect(c1.occurrenceKey, isNot(equals(c2.occurrenceKey)));

      // Explicitly compute expected payload and hash
      final expectedPayload1 = 'rule_identity|${c1.dueAt.toIso8601String()}|1';
      final expectedHash1 =
          sha256.convert(utf8.encode(expectedPayload1)).toString();
      expect(c1.occurrenceKey, equals(expectedHash1));

      final expectedPayload2 = 'rule_identity|${c2.dueAt.toIso8601String()}|2';
      final expectedHash2 =
          sha256.convert(utf8.encode(expectedPayload2)).toString();
      expect(c2.occurrenceKey, equals(expectedHash2));
    });
  });
}
