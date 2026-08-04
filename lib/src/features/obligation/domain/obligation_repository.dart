import 'obligation.dart';
import 'schedule_rule.dart';

abstract class ObligationRepository {
  Future<void> createDraftObligation(Obligation obligation);
  Future<void> updateDraftObligation(Obligation obligation);
  Future<void> confirmObligation(String obligationId);
  Future<void> markObligationFulfilled(String obligationId);
  Future<List<Obligation>> getObligationsForAgreement(String agreementId);
  Future<List<Obligation>> getObligationsForClause(String clauseId);
  Future<Obligation?> getObligationById(String obligationId);

  Future<void> createScheduleRule(ScheduleRule rule);
  Future<ScheduleRule?> getScheduleRuleForObligation(String obligationId);
}
