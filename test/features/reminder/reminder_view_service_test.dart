import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_repository.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_version.dart';
import 'package:tekmerion/src/features/clause/domain/clause.dart';
import 'package:tekmerion/src/features/clause/domain/clause_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/schedule_rule.dart';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_view_service.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reconciliation_plan.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_repository.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_temporal_status.dart';

class FakeReminderRepository implements ReminderRepository {
  List<ReminderInstance> today = [];
  List<ReminderInstance> upcoming = [];

  @override Future<void> applyReconciliationPlan(ReconciliationPlan plan, DateTime appliedAt) async {}
  @override Future<void> cancelFutureForObligation({required String obligationId, required DateTime cancelledAt}) async {}
  @override Future<ReminderInstance?> getById(String id) async => null;
  @override Future<ReminderInstance?> getByOccurrence({required String scheduleRuleId, required String occurrenceKey}) async => null;
  @override Future<List<ReminderInstance>> getForAgreement(String agreementId) async => [];
  @override Future<List<ReminderInstance>> getForObligation(String obligationId) async => [];
  @override Future<List<ReminderInstance>> getForScheduleRule(String scheduleRuleId) async => [];
  @override Future<List<ReminderInstance>> getToday(DateTime now) async => today;
  @override Future<List<ReminderInstance>> getUpcoming(DateTime now) async => upcoming;
  @override Future<void> insertBatchIfAbsent(List<ReminderInstance> reminders) async {}
  @override Future<void> insertIfAbsent(ReminderInstance reminder) async {}
  @override Future<void> markNotificationFailed({required String reminderId, required String errorCode, required DateTime attemptedAt}) async {}
  @override Future<void> markNotificationScheduled({required String reminderId, required int localNotificationId, required DateTime scheduledAt}) async {}
  @override Future<void> supersedeFutureForRule({required String scheduleRuleId, required int newGenerationVersion, required DateTime supersededAt}) async {}
  @override Future<void> transitionState({required String reminderId, required ReminderState expectedCurrentState, required ReminderState targetState, required DateTime occurredAt}) async {}
}

class FakeAgreementRepository implements AgreementRepository {
  List<Agreement> agreements = [];

  @override Future<List<Agreement>> getAllAgreements() async => agreements;
  @override Future<EvidenceEnvelope?> getEvidenceAssetById(String evidenceId) async => null;
  @override Future<List<AgreementVersion>> getVersionsForAgreement(String agreementId) async => [];
  @override Future<void> importAgreementTransaction({required EvidenceEnvelope evidence, required Agreement agreement, required AgreementVersion version}) async {}
}

class FakeObligationRepository implements ObligationRepository {
  List<Obligation> obligations = [];

  @override Future<void> confirmObligation(String obligationId) async {}
  @override Future<void> createDraftObligation(Obligation obligation) async {}
  @override Future<void> createScheduleRule(ScheduleRule rule) async {}
  @override Future<Obligation?> getObligationById(String obligationId) async {
    return obligations.where((o) => o.id == obligationId).firstOrNull;
  }
  @override Future<List<Obligation>> getObligationsForAgreement(String agreementId) async => [];
  @override Future<List<Obligation>> getObligationsForClause(String clauseId) async => [];
  @override Future<ScheduleRule?> getScheduleRuleForObligation(String obligationId) async => null;
  @override Future<void> markObligationFulfilled(String obligationId) async {}
  @override Future<void> updateDraftObligation(Obligation obligation) async {}
}

class FakeClauseRepository implements ClauseRepository {
  List<Clause> clauses = [];

  @override Future<void> confirmClause(String clauseId) async {}
  @override Future<void> createDraftClause(Clause clause) async {}
  @override Future<Clause?> getClauseById(String id) async {
    return clauses.where((c) => c.id == id).firstOrNull;
  }
  @override Future<List<Clause>> getClausesForAgreementVersion(String agreementVersionId) async => [];
  @override Future<void> updateDraftClause(Clause clause) async {}
}

void main() {
  late FakeReminderRepository reminderRepository;
  late FakeAgreementRepository agreementRepository;
  late FakeObligationRepository obligationRepository;
  late FakeClauseRepository clauseRepository;
  late ReminderViewService service;

  setUp(() {
    reminderRepository = FakeReminderRepository();
    agreementRepository = FakeAgreementRepository();
    obligationRepository = FakeObligationRepository();
    clauseRepository = FakeClauseRepository();

    service = ReminderViewService(
      reminderRepository: reminderRepository,
      agreementRepository: agreementRepository,
      obligationRepository: obligationRepository,
      clauseRepository: clauseRepository,
    );
  });

  ReminderInstance createReminder({
    required String id,
    required DateTime dueAt,
    required String agreementId,
    required String obligationId,
  }) {
    return ReminderInstance(
      id: id,
      agreementId: agreementId,
      obligationId: obligationId,
      scheduleRuleId: 'rule1',
      occurrenceKey: id,
      dueAt: dueAt,
      remindAt: dueAt,
      timezone: 'UTC',
      state: ReminderState.scheduled,
      notificationState: NotificationSchedulingState.pending,
      title: 'Test Reminder',
      body: 'Test Body',
      provenanceSummary: 'Test Provenance',
      generationVersion: 1,
      generatedAt: DateTime.now().toUtc(),
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  test('getTodayViewModels maps related data correctly', () async {
    final nowUtc = DateTime.utc(2026, 8, 5, 12, 0);

    agreementRepository.agreements.add(Agreement(
      id: 'a1',
      title: 'Lease Agreement',
      agreementType: 'lease',
      status: AgreementStatus.active,
      createdAt: nowUtc,
    ),);

    obligationRepository.obligations.add(Obligation(
      id: 'o1',
      agreementId: 'a1',
      sourceClauseId: 'c1',
      sourceType: ObligationSourceType.contractual,
      title: 'Pay Rent',
      description: 'Monthly rent payment',
      obligationCategory: 'payment',
      status: ObligationStatus.confirmed,
      createdAt: nowUtc,
    ),);

    clauseRepository.clauses.add(Clause(
      id: 'c1',
      agreementVersionId: 'av1',
      heading: '3. Rent',
      sourceText: 'Pay rent',
      pageStart: 1,
      pageEnd: 1,
      reviewState: ClauseReviewState.confirmed,
      createdAt: nowUtc,
    ),);

    reminderRepository.today.add(createReminder(
      id: 'r1',
      dueAt: nowUtc,
      agreementId: 'a1',
      obligationId: 'o1',
    ),);

    // A reminder with missing relations
    reminderRepository.today.add(createReminder(
      id: 'r2',
      dueAt: nowUtc,
      agreementId: 'missing-a',
      obligationId: 'missing-o',
    ),);

    final viewModels = await service.getTodayViewModels(nowUtc, const Duration(days: 1));

    expect(viewModels.length, equals(2));

    final r1Model = viewModels.firstWhere((vm) => vm.reminderId == 'r1');
    expect(r1Model.agreementTitle, equals('Lease Agreement'));
    expect(r1Model.obligationTitle, equals('Pay Rent'));
    expect(r1Model.clauseReference, equals('3. Rent'));
    expect(r1Model.temporalStatus, equals(ReminderTemporalStatus.dueToday));
    expect(r1Model.canAcknowledge, isTrue);
    expect(r1Model.canComplete, isTrue);

    final r2Model = viewModels.firstWhere((vm) => vm.reminderId == 'r2');
    expect(r2Model.agreementTitle, equals('Unknown Agreement'));
    expect(r2Model.obligationTitle, equals('Unknown Obligation'));
    expect(r2Model.clauseReference, isNull);
  });
}
