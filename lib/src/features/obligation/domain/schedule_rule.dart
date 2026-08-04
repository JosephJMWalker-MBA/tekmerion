import 'package:meta/meta.dart';

enum ScheduleRuleType {
  oneTime,
  monthlyDayOfMonth,
  intervalDays,
  manualOnly,
}

@immutable
class ScheduleRule {
  const ScheduleRule({
    required this.id,
    required this.obligationId,
    required this.ruleType,
    required this.timezone,
    required this.startAt,
    this.endAt,
    this.recurrenceExpression,
    required this.leadTimeSeconds,
    required this.gracePeriodSeconds,
    this.sourceText,
    required this.confirmedAt,
  });

  final String id;
  final String obligationId;
  final ScheduleRuleType ruleType;
  final String timezone;
  final DateTime startAt;
  final DateTime? endAt;
  final String? recurrenceExpression;
  final int leadTimeSeconds;
  final int gracePeriodSeconds;
  final String? sourceText;
  final DateTime confirmedAt;

  ScheduleRule copyWith({
    String? id,
    String? obligationId,
    ScheduleRuleType? ruleType,
    String? timezone,
    DateTime? startAt,
    DateTime? endAt,
    String? recurrenceExpression,
    int? leadTimeSeconds,
    int? gracePeriodSeconds,
    String? sourceText,
    DateTime? confirmedAt,
  }) {
    return ScheduleRule(
      id: id ?? this.id,
      obligationId: obligationId ?? this.obligationId,
      ruleType: ruleType ?? this.ruleType,
      timezone: timezone ?? this.timezone,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      recurrenceExpression: recurrenceExpression ?? this.recurrenceExpression,
      leadTimeSeconds: leadTimeSeconds ?? this.leadTimeSeconds,
      gracePeriodSeconds: gracePeriodSeconds ?? this.gracePeriodSeconds,
      sourceText: sourceText ?? this.sourceText,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduleRule &&
        other.id == id &&
        other.obligationId == obligationId &&
        other.ruleType == ruleType &&
        other.timezone == timezone &&
        other.startAt == startAt &&
        other.endAt == endAt &&
        other.recurrenceExpression == recurrenceExpression &&
        other.leadTimeSeconds == leadTimeSeconds &&
        other.gracePeriodSeconds == gracePeriodSeconds &&
        other.sourceText == sourceText &&
        other.confirmedAt == confirmedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      obligationId,
      ruleType,
      timezone,
      startAt,
      endAt,
      recurrenceExpression,
      leadTimeSeconds,
      gracePeriodSeconds,
      sourceText,
      confirmedAt,
    );
  }
}
