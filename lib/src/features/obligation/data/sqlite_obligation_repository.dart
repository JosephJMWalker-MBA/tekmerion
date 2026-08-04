import 'package:sqflite/sqflite.dart';
import '../domain/obligation.dart';
import '../domain/obligation_repository.dart';
import '../domain/schedule_rule.dart';

class SqliteObligationRepository implements ObligationRepository {
  SqliteObligationRepository(this._databaseFactory, this._dbPath);

  final Future<Database> Function(String path) _databaseFactory;
  final String _dbPath;

  Future<Database> _getDb() => _databaseFactory(_dbPath);

  @override
  Future<void> createDraftObligation(Obligation obligation) async {
    if (obligation.status != ObligationStatus.draft) {
      throw ArgumentError('Obligation must be in draft state for creation.');
    }
    final db = await _getDb();
    await db.insert('obligations', _obligationToMap(obligation));
  }

  @override
  Future<void> updateDraftObligation(Obligation obligation) async {
    final db = await _getDb();

    final existing = await db.query(
      'obligations',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [obligation.id],
    );

    if (existing.isEmpty) {
      throw StateError('Obligation not found.');
    }

    if (existing.first['status'] != ObligationStatus.draft.name) {
      throw StateError('Only draft obligations can be updated.');
    }

    await db.update(
      'obligations',
      _obligationToMap(obligation),
      where: 'id = ? AND status = ?',
      whereArgs: [obligation.id, ObligationStatus.draft.name],
    );
  }

  @override
  Future<void> confirmObligation(String obligationId) async {
    final db = await _getDb();

    final existing = await db.query(
      'obligations',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [obligationId],
    );

    if (existing.isEmpty) {
      throw StateError('Obligation not found.');
    }

    if (existing.first['status'] != ObligationStatus.draft.name) {
      throw StateError('Only draft obligations can be confirmed.');
    }

    await db.update(
      'obligations',
      {
        'status': ObligationStatus.confirmed.name,
        'confirmed_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [obligationId],
    );
  }

  @override
  Future<void> markObligationFulfilled(String obligationId) async {
    final db = await _getDb();

    final existing = await db.query(
      'obligations',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [obligationId],
    );

    if (existing.isEmpty) {
      throw StateError('Obligation not found.');
    }

    if (existing.first['status'] != ObligationStatus.confirmed.name &&
        existing.first['status'] != ObligationStatus.due.name &&
        existing.first['status'] != ObligationStatus.upcoming.name) {
      throw StateError('Only active obligations can be fulfilled.');
    }

    await db.update(
      'obligations',
      {
        'status': ObligationStatus.fulfilled.name,
      },
      where: 'id = ?',
      whereArgs: [obligationId],
    );
  }

  @override
  Future<List<Obligation>> getObligationsForAgreement(
    String agreementId,
  ) async {
    final db = await _getDb();
    final results = await db.query(
      'obligations',
      where: 'agreement_id = ?',
      whereArgs: [agreementId],
    );
    return results.map(_obligationFromMap).toList();
  }

  @override
  Future<List<Obligation>> getObligationsForClause(String clauseId) async {
    final db = await _getDb();
    final results = await db.query(
      'obligations',
      where: 'source_clause_id = ?',
      whereArgs: [clauseId],
    );
    return results.map(_obligationFromMap).toList();
  }

  @override
  Future<Obligation?> getObligationById(String obligationId) async {
    final db = await _getDb();
    final results = await db.query(
      'obligations',
      where: 'id = ?',
      whereArgs: [obligationId],
    );
    if (results.isEmpty) return null;
    return _obligationFromMap(results.first);
  }

  @override
  Future<void> createScheduleRule(ScheduleRule rule) async {
    final db = await _getDb();
    await db.insert('schedule_rules', _scheduleRuleToMap(rule));
  }

  @override
  Future<ScheduleRule?> getScheduleRuleForObligation(
    String obligationId,
  ) async {
    final db = await _getDb();
    final results = await db.query(
      'schedule_rules',
      where: 'obligation_id = ?',
      whereArgs: [obligationId],
    );
    if (results.isEmpty) return null;
    return _scheduleRuleFromMap(results.first);
  }

  Map<String, Object?> _obligationToMap(Obligation obligation) {
    return {
      'id': obligation.id,
      'agreement_id': obligation.agreementId,
      'source_clause_id': obligation.sourceClauseId,
      'source_type': obligation.sourceType.name,
      'responsible_party_id': obligation.responsiblePartyId,
      'benefited_party_id': obligation.benefitedPartyId,
      'title': obligation.title,
      'description': obligation.description,
      'obligation_category': obligation.obligationCategory,
      'status': obligation.status.name,
      'confirmed_at': obligation.confirmedAt?.toUtc().toIso8601String(),
      'confirmed_by_party_id': obligation.confirmedByPartyId,
      'superseded_by_obligation_id': obligation.supersededByObligationId,
      'created_at': obligation.createdAt.toUtc().toIso8601String(),
    };
  }

  Obligation _obligationFromMap(Map<String, Object?> map) {
    return Obligation(
      id: map['id'] as String,
      agreementId: map['agreement_id'] as String,
      sourceClauseId: map['source_clause_id'] as String?,
      sourceType:
          ObligationSourceType.values.byName(map['source_type'] as String),
      responsiblePartyId: map['responsible_party_id'] as String?,
      benefitedPartyId: map['benefited_party_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String,
      obligationCategory: map['obligation_category'] as String,
      status: ObligationStatus.values.byName(map['status'] as String),
      confirmedAt: map['confirmed_at'] != null
          ? DateTime.parse(map['confirmed_at'] as String).toLocal()
          : null,
      confirmedByPartyId: map['confirmed_by_party_id'] as String?,
      supersededByObligationId: map['superseded_by_obligation_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, Object?> _scheduleRuleToMap(ScheduleRule rule) {
    return {
      'id': rule.id,
      'obligation_id': rule.obligationId,
      'rule_type': rule.ruleType.name,
      'timezone': rule.timezone,
      'start_at': rule.startAt.toUtc().toIso8601String(),
      'end_at': rule.endAt?.toUtc().toIso8601String(),
      'recurrence_expression': rule.recurrenceExpression,
      'lead_time_seconds': rule.leadTimeSeconds,
      'grace_period_seconds': rule.gracePeriodSeconds,
      'source_text': rule.sourceText,
      'confirmed_at': rule.confirmedAt.toUtc().toIso8601String(),
    };
  }

  ScheduleRule _scheduleRuleFromMap(Map<String, Object?> map) {
    return ScheduleRule(
      id: map['id'] as String,
      obligationId: map['obligation_id'] as String,
      ruleType: ScheduleRuleType.values.byName(map['rule_type'] as String),
      timezone: map['timezone'] as String,
      startAt: DateTime.parse(map['start_at'] as String).toLocal(),
      endAt: map['end_at'] != null
          ? DateTime.parse(map['end_at'] as String).toLocal()
          : null,
      recurrenceExpression: map['recurrence_expression'] as String?,
      leadTimeSeconds: map['lead_time_seconds'] as int,
      gracePeriodSeconds: map['grace_period_seconds'] as int,
      sourceText: map['source_text'] as String?,
      confirmedAt: DateTime.parse(map['confirmed_at'] as String).toLocal(),
    );
  }
}
