import 'clause.dart';

abstract class ClauseRepository {
  /// Persists a newly created draft clause.
  Future<void> createDraftClause(Clause clause);

  /// Updates an existing draft clause.
  Future<void> updateDraftClause(Clause clause);

  /// Promotes a draft clause to confirmed.
  Future<void> confirmClause(String clauseId);

  /// Retrieves a clause by ID.
  Future<Clause?> getClauseById(String id);

  /// Retrieves all clauses for a given AgreementVersion.
  Future<List<Clause>> getClausesForAgreementVersion(String agreementVersionId);
}
