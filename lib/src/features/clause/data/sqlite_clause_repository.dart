import 'package:sqflite/sqflite.dart';
import '../domain/clause.dart';
import '../domain/clause_repository.dart';

class SqliteClauseRepository implements ClauseRepository {
  SqliteClauseRepository(this._databaseFactory, this._dbPath);

  final Future<Database> Function(String path) _databaseFactory;
  final String _dbPath;

  Future<Database> _getDb() => _databaseFactory(_dbPath);

  @override
  Future<void> createDraftClause(Clause clause) async {
    if (clause.reviewState != ClauseReviewState.draft) {
      throw ArgumentError('Clause must be in draft state for creation.');
    }

    final db = await _getDb();
    await db.insert('clauses', _toMap(clause));
  }

  @override
  Future<void> updateDraftClause(Clause clause) async {
    final db = await _getDb();

    final existing = await db.query(
      'clauses',
      columns: ['review_state'],
      where: 'id = ?',
      whereArgs: [clause.id],
    );

    if (existing.isEmpty) {
      throw StateError('Clause not found.');
    }

    if (existing.first['review_state'] != ClauseReviewState.draft.name) {
      throw StateError('Only draft clauses can be updated.');
    }

    await db.update(
      'clauses',
      _toMap(clause),
      where: 'id = ? AND review_state = ?',
      whereArgs: [clause.id, ClauseReviewState.draft.name],
    );
  }

  @override
  Future<void> confirmClause(String clauseId) async {
    final db = await _getDb();

    final existing = await db.query(
      'clauses',
      columns: ['review_state'],
      where: 'id = ?',
      whereArgs: [clauseId],
    );

    if (existing.isEmpty) {
      throw StateError('Clause not found.');
    }

    if (existing.first['review_state'] != ClauseReviewState.draft.name) {
      throw StateError('Only draft clauses can be confirmed.');
    }

    await db.update(
      'clauses',
      {
        'review_state': ClauseReviewState.confirmed.name,
        'confirmed_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [clauseId],
    );
  }

  @override
  Future<Clause?> getClauseById(String id) async {
    final db = await _getDb();
    final results = await db.query(
      'clauses',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  @override
  Future<List<Clause>> getClausesForAgreementVersion(
    String agreementVersionId,
  ) async {
    final db = await _getDb();
    final results = await db.query(
      'clauses',
      where: 'agreement_version_id = ?',
      whereArgs: [agreementVersionId],
      orderBy: 'page_start ASC',
    );

    return results.map(_fromMap).toList();
  }

  Map<String, Object?> _toMap(Clause clause) {
    return {
      'id': clause.id,
      'agreement_version_id': clause.agreementVersionId,
      'parent_clause_id': clause.parentClauseId,
      'heading': clause.heading,
      'clause_number': clause.clauseNumber,
      'source_text': clause.sourceText,
      'normalized_text': clause.normalizedText,
      'page_start': clause.pageStart,
      'page_end': clause.pageEnd,
      'character_start': clause.characterStart,
      'character_end': clause.characterEnd,
      'parse_confidence': clause.parseConfidence,
      'review_state': clause.reviewState.name,
      'created_at': clause.createdAt.toUtc().toIso8601String(),
      'confirmed_at': clause.confirmedAt?.toUtc().toIso8601String(),
    };
  }

  Clause _fromMap(Map<String, Object?> map) {
    return Clause(
      id: map['id'] as String,
      agreementVersionId: map['agreement_version_id'] as String,
      parentClauseId: map['parent_clause_id'] as String?,
      heading: map['heading'] as String?,
      clauseNumber: map['clause_number'] as String?,
      sourceText: map['source_text'] as String,
      normalizedText: map['normalized_text'] as String?,
      pageStart: map['page_start'] as int,
      pageEnd: map['page_end'] as int,
      characterStart: map['character_start'] as int?,
      characterEnd: map['character_end'] as int?,
      parseConfidence: map['parse_confidence'] as double?,
      reviewState:
          ClauseReviewState.values.byName(map['review_state'] as String),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      confirmedAt: map['confirmed_at'] != null
          ? DateTime.parse(map['confirmed_at'] as String).toLocal()
          : null,
    );
  }
}
