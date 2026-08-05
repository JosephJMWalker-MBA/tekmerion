import 'package:sqflite/sqflite.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reconciliation_plan.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_repository.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';

typedef UtcNow = DateTime Function();

class SqliteReminderRepository implements ReminderRepository {
  SqliteReminderRepository(
    this._databaseFactory,
    this._dbPath, {
    UtcNow? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Future<Database> Function(String path) _databaseFactory;
  final String _dbPath;
  final UtcNow _nowUtc;

  Future<Database> _getDb() => _databaseFactory(_dbPath);

  @override
  Future<void> insertIfAbsent(ReminderInstance reminder) async {
    final db = await _getDb();
    await db.insert(
      'reminders',
      _toMap(reminder),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> insertBatchIfAbsent(List<ReminderInstance> reminders) async {
    if (reminders.isEmpty) return;
    final db = await _getDb();
    await db.transaction((txn) async {
      for (final reminder in reminders) {
        await txn.insert(
          'reminders',
          _toMap(reminder),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<ReminderInstance?> getById(String id) async {
    final db = await _getDb();
    final results = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  @override
  Future<ReminderInstance?> getByOccurrence({
    required String scheduleRuleId,
    required String occurrenceKey,
  }) async {
    final db = await _getDb();
    final results = await db.query(
      'reminders',
      where: 'schedule_rule_id = ? AND occurrence_key = ?',
      whereArgs: [scheduleRuleId, occurrenceKey],
    );
    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  @override
  Future<List<ReminderInstance>> getForAgreement(String agreementId) async {
    final db = await _getDb();
    final results = await db.query(
      'reminders',
      where: 'agreement_id = ?',
      whereArgs: [agreementId],
      orderBy: 'due_at ASC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<List<ReminderInstance>> getForObligation(String obligationId) async {
    final db = await _getDb();
    final results = await db.query(
      'reminders',
      where: 'obligation_id = ?',
      whereArgs: [obligationId],
      orderBy: 'due_at ASC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<List<ReminderInstance>> getForScheduleRule(
    String scheduleRuleId,
  ) async {
    final db = await _getDb();
    final results = await db.query(
      'reminders',
      where: 'schedule_rule_id = ?',
      whereArgs: [scheduleRuleId],
      orderBy: 'due_at ASC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<List<ReminderInstance>> getToday(DateTime now) async {
    final db = await _getDb();
    final isoNow = now.toUtc().toIso8601String();
    final results = await db.query(
      'reminders',
      where: 'due_at <= ? AND state IN (?, ?)',
      whereArgs: [
        isoNow,
        ReminderState.scheduled.name,
        ReminderState.acknowledged.name,
      ],
      orderBy: 'due_at ASC, id ASC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<List<ReminderInstance>> getUpcoming(DateTime now) async {
    final db = await _getDb();
    final isoNow = now.toUtc().toIso8601String();
    final results = await db.query(
      'reminders',
      where: 'due_at > ? AND state IN (?, ?)',
      whereArgs: [
        isoNow,
        ReminderState.scheduled.name,
        ReminderState.acknowledged.name,
      ],
      orderBy: 'due_at ASC, id ASC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<void> transitionState({
    required String reminderId,
    required ReminderState expectedCurrentState,
    required ReminderState targetState,
    required DateTime occurredAt,
  }) async {
    final db = await _getDb();
    final isoOccurred = occurredAt.toUtc().toIso8601String();

    final updateFields = <String, Object?>{
      'state': targetState.name,
      'updated_at': isoOccurred,
    };

    switch (targetState) {
      case ReminderState.acknowledged:
        updateFields['acknowledged_at'] = isoOccurred;
        break;
      case ReminderState.dismissed:
        updateFields['dismissed_at'] = isoOccurred;
        break;
      case ReminderState.completed:
        updateFields['completed_at'] = isoOccurred;
        break;
      case ReminderState.cancelled:
        updateFields['cancelled_at'] = isoOccurred;
        break;
      case ReminderState.superseded:
        updateFields['superseded_at'] = isoOccurred;
        break;
      case ReminderState.expired:
        updateFields['expired_at'] = isoOccurred;
        break;
      case ReminderState.scheduled:
        break; // No terminal timestamp for active states
    }

    final count = await db.update(
      'reminders',
      updateFields,
      where: 'id = ? AND state = ?',
      whereArgs: [reminderId, expectedCurrentState.name],
    );

    if (count == 0) {
      throw StateError(
        'Invalid state transition from ${expectedCurrentState.name} to ${targetState.name} for reminder $reminderId',
      );
    }
  }

  @override
  Future<void> markNotificationScheduled({
    required String reminderId,
    required int localNotificationId,
    required DateTime scheduledAt,
  }) async {
    final db = await _getDb();
    await db.update(
      'reminders',
      {
        'notification_state': NotificationSchedulingState.scheduled.name,
        'local_notification_id': localNotificationId,
        'notification_scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'updated_at': _nowUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  @override
  Future<void> markNotificationFailed({
    required String reminderId,
    required String errorCode,
    required DateTime attemptedAt,
  }) async {
    final db = await _getDb();
    await db.update(
      'reminders',
      {
        'notification_state': NotificationSchedulingState.failed.name,
        'notification_error_code': errorCode,
        'notification_attempted_at': attemptedAt.toUtc().toIso8601String(),
        'updated_at': _nowUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  @override
  Future<void> supersedeFutureForRule({
    required String scheduleRuleId,
    required int newGenerationVersion,
    required DateTime supersededAt,
  }) async {
    final db = await _getDb();
    await db.update(
      'reminders',
      {
        'state': ReminderState.superseded.name,
        'superseded_at': supersededAt.toUtc().toIso8601String(),
        'updated_at': _nowUtc().toIso8601String(),
      },
      where:
          'schedule_rule_id = ? AND generation_version < ? AND state IN (?, ?)',
      whereArgs: [
        scheduleRuleId,
        newGenerationVersion,
        ReminderState.scheduled.name,
        ReminderState.acknowledged.name,
      ],
    );
  }

  @override
  Future<void> cancelFutureForObligation({
    required String obligationId,
    required DateTime cancelledAt,
  }) async {
    final db = await _getDb();
    await db.update(
      'reminders',
      {
        'state': ReminderState.cancelled.name,
        'cancelled_at': cancelledAt.toUtc().toIso8601String(),
        'updated_at': _nowUtc().toIso8601String(),
      },
      where: 'obligation_id = ? AND state IN (?, ?)',
      whereArgs: [
        obligationId,
        ReminderState.scheduled.name,
        ReminderState.acknowledged.name,
      ],
    );
  }

  @override
  Future<void> applyReconciliationPlan(
    ReconciliationPlan plan,
    DateTime appliedAt,
  ) async {
    final db = await _getDb();
    final isoApplied = appliedAt.toUtc().toIso8601String();

    await db.transaction((txn) async {
      // 1. Handle Inserts
      for (final op in plan.inserts) {
        final map = _toMap(op.reminder);
        map['local_notification_id'] = op.localNotificationId;
        map['updated_at'] = isoApplied;
        await txn.insert(
          'reminders',
          map,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 2. Handle Supersessions
      for (final op in plan.supersedes) {
        await txn.update(
          'reminders',
          {
            'state': ReminderState.superseded.name,
            'superseded_at': isoApplied,
            'updated_at': isoApplied,
          },
          where: 'id = ? AND state IN (?, ?)',
          whereArgs: [
            op.reminder.id,
            ReminderState.scheduled.name,
            ReminderState.acknowledged.name,
          ],
        );
      }

      // 3. Handle Cancellations
      for (final op in plan.cancels) {
        await txn.update(
          'reminders',
          {
            'state': ReminderState.cancelled.name,
            'cancelled_at': isoApplied,
            'updated_at': isoApplied,
          },
          where: 'id = ? AND state IN (?, ?)',
          whereArgs: [
            op.reminder.id,
            ReminderState.scheduled.name,
            ReminderState.acknowledged.name,
          ],
        );
      }
    });
  }

  Map<String, Object?> _toMap(ReminderInstance reminder) {
    return {
      'id': reminder.id,
      'agreement_id': reminder.agreementId,
      'obligation_id': reminder.obligationId,
      'schedule_rule_id': reminder.scheduleRuleId,
      'occurrence_key': reminder.occurrenceKey,
      'due_at': reminder.dueAt.toUtc().toIso8601String(),
      'remind_at': reminder.remindAt.toUtc().toIso8601String(),
      'timezone': reminder.timezone,
      'state': reminder.state.name,
      'generation_version': reminder.generationVersion,
      'generated_at': reminder.generatedAt.toUtc().toIso8601String(),
      'acknowledged_at': reminder.acknowledgedAt?.toUtc().toIso8601String(),
      'dismissed_at': reminder.dismissedAt?.toUtc().toIso8601String(),
      'completed_at': reminder.completedAt?.toUtc().toIso8601String(),
      'cancelled_at': reminder.cancelledAt?.toUtc().toIso8601String(),
      'superseded_at': reminder.supersededAt?.toUtc().toIso8601String(),
      'expired_at': reminder.expiredAt?.toUtc().toIso8601String(),
      'local_notification_id': reminder.localNotificationId,
      'notification_state': reminder.notificationState.name,
      'notification_attempted_at':
          reminder.notificationAttemptedAt?.toUtc().toIso8601String(),
      'notification_scheduled_at':
          reminder.notificationScheduledAt?.toUtc().toIso8601String(),
      'notification_error_code': reminder.notificationErrorCode,
      'title': reminder.title,
      'body': reminder.body,
      'provenance_summary': reminder.provenanceSummary,
      'created_at': reminder.createdAt.toUtc().toIso8601String(),
      'updated_at': reminder.updatedAt.toUtc().toIso8601String(),
    };
  }

  ReminderInstance _fromMap(Map<String, Object?> map) {
    return ReminderInstance(
      id: map['id'] as String,
      agreementId: map['agreement_id'] as String,
      obligationId: map['obligation_id'] as String,
      scheduleRuleId: map['schedule_rule_id'] as String,
      occurrenceKey: map['occurrence_key'] as String,
      dueAt: DateTime.parse(map['due_at'] as String).toUtc(),
      remindAt: DateTime.parse(map['remind_at'] as String).toUtc(),
      timezone: map['timezone'] as String,
      state: ReminderState.values.byName(map['state'] as String),
      generationVersion: map['generation_version'] as int,
      generatedAt: DateTime.parse(map['generated_at'] as String).toUtc(),
      acknowledgedAt: map['acknowledged_at'] != null
          ? DateTime.parse(map['acknowledged_at'] as String).toUtc()
          : null,
      dismissedAt: map['dismissed_at'] != null
          ? DateTime.parse(map['dismissed_at'] as String).toUtc()
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String).toUtc()
          : null,
      cancelledAt: map['cancelled_at'] != null
          ? DateTime.parse(map['cancelled_at'] as String).toUtc()
          : null,
      supersededAt: map['superseded_at'] != null
          ? DateTime.parse(map['superseded_at'] as String).toUtc()
          : null,
      expiredAt: map['expired_at'] != null
          ? DateTime.parse(map['expired_at'] as String).toUtc()
          : null,
      localNotificationId: map['local_notification_id'] as int?,
      notificationState: NotificationSchedulingState.values
          .byName(map['notification_state'] as String),
      notificationAttemptedAt: map['notification_attempted_at'] != null
          ? DateTime.parse(map['notification_attempted_at'] as String).toUtc()
          : null,
      notificationScheduledAt: map['notification_scheduled_at'] != null
          ? DateTime.parse(map['notification_scheduled_at'] as String).toUtc()
          : null,
      notificationErrorCode: map['notification_error_code'] as String?,
      title: map['title'] as String,
      body: map['body'] as String,
      provenanceSummary: map['provenance_summary'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
    );
  }
}
