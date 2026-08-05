import 'package:tekmerion/src/features/agreement/domain/agreement_repository.dart';
import 'package:tekmerion/src/features/clause/domain/clause_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation_repository.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_temporal_status_resolver.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_instance.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_repository.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_card_view_model.dart';

class ReminderViewService {
  ReminderViewService({
    required this.reminderRepository,
    required this.agreementRepository,
    required this.obligationRepository,
    required this.clauseRepository,
  });

  final ReminderRepository reminderRepository;
  final AgreementRepository agreementRepository;
  final ObligationRepository obligationRepository;
  final ClauseRepository clauseRepository;

  /// Retrieves view models for reminders due today or earlier.
  Future<List<ReminderCardViewModel>> getTodayViewModels(DateTime nowUtc, Duration gracePeriod) async {
    final reminders = await reminderRepository.getToday(nowUtc);
    return _mapToViewModels(reminders, nowUtc, gracePeriod);
  }

  /// Retrieves view models for upcoming reminders.
  Future<List<ReminderCardViewModel>> getUpcomingViewModels(DateTime nowUtc, Duration gracePeriod, {int daysHorizon = 30}) async {
    final allUpcoming = await reminderRepository.getUpcoming(nowUtc);
    // Filter by horizon
    final horizonEnd = nowUtc.add(Duration(days: daysHorizon));
    final withinHorizon = allUpcoming.where((r) => r.dueAt.isBefore(horizonEnd)).toList();
    return _mapToViewModels(withinHorizon, nowUtc, gracePeriod);
  }

  Future<List<ReminderCardViewModel>> _mapToViewModels(
    List<ReminderInstance> reminders,
    DateTime nowUtc,
    Duration gracePeriod,
  ) async {
    // Cache to avoid duplicate DB queries for the same parent entities
    final agreementsCache = <String, String>{};
    final obligationsCache = <String, String>{};
    final clausesCache = <String, String>{};

    final viewModels = <ReminderCardViewModel>[];

    for (final reminder in reminders) {
      // Resolve Agreement Title
      String agreementTitle = 'Unknown Agreement';
      if (agreementsCache.containsKey(reminder.agreementId)) {
        agreementTitle = agreementsCache[reminder.agreementId]!;
      } else {
        final allAgreements = await agreementRepository.getAllAgreements();
        final agreement = allAgreements.where((a) => a.id == reminder.agreementId).firstOrNull;
        if (agreement != null) {
          agreementTitle = agreement.title;
          agreementsCache[reminder.agreementId] = agreementTitle;
        }
      }

      // Resolve Obligation Title
      String obligationTitle = 'Unknown Obligation';
      String? clauseId;
      if (obligationsCache.containsKey(reminder.obligationId)) {
        obligationTitle = obligationsCache[reminder.obligationId]!;
        // Note: caching clause ID here isn't done to keep it simple, we re-fetch if needed
        final obligation = await obligationRepository.getObligationById(reminder.obligationId);
        clauseId = obligation?.sourceClauseId;
      } else {
        final obligation = await obligationRepository.getObligationById(reminder.obligationId);
        if (obligation != null) {
          obligationTitle = obligation.title;
          clauseId = obligation.sourceClauseId;
          obligationsCache[reminder.obligationId] = obligationTitle;
        }
      }

      // Resolve Clause Reference
      String? clauseReference;
      if (clauseId != null) {
        if (clausesCache.containsKey(clauseId)) {
          clauseReference = clausesCache[clauseId]!;
        } else {
          final clause = await clauseRepository.getClauseById(clauseId);
          if (clause != null) {
            clauseReference = clause.heading ?? clause.clauseNumber;
            clausesCache[clauseId] = clauseReference ?? '';
          }
        }
      }

      final temporalStatus = ReminderTemporalStatusResolver.resolve(
        reminder: reminder,
        currentUtc: nowUtc,
        gracePeriod: gracePeriod,
      );

      final canAcknowledge = reminder.state == ReminderState.scheduled;
      final canDismiss = reminder.state == ReminderState.scheduled || reminder.state == ReminderState.acknowledged;
      final canComplete = reminder.state != ReminderState.completed && !reminder.state.isTerminal;

      // Note: This relies on standard display formatting. We don't have a specific requirement 
      // on format so we just provide the ISO string or a simple representation.
      final displayTime = _formatLocal(reminder.dueAt, reminder.timezone);

      viewModels.add(ReminderCardViewModel(
        reminderId: reminder.id,
        agreementId: reminder.agreementId,
        agreementTitle: agreementTitle,
        obligationId: reminder.obligationId,
        obligationTitle: obligationTitle,
        clauseReference: clauseReference,
        dueAtUtc: reminder.dueAt,
        timezone: reminder.timezone,
        dueAtDisplay: displayTime,
        reminderState: reminder.state,
        temporalStatus: temporalStatus,
        notificationStatus: reminder.notificationState,
        canAcknowledge: canAcknowledge,
        canDismiss: canDismiss,
        canComplete: canComplete,
      ),);
    }

    return viewModels;
  }

  String _formatLocal(DateTime utc, String timezone) {
    // For simplicity, we just use local conversion without full timezone library text formatting,
    // or return a standard ISO representation. In a real app we'd use intl and timezone.
    return "${utc.toIso8601String()} ($timezone)";
  }
}
