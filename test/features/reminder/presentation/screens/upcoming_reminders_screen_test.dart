import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_repository.dart';
import 'package:tekmerion/src/features/clause/domain/clause_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation_repository.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_reconciliation_service.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_view_service.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_repository.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_card_view_model.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_temporal_status.dart';
import 'package:tekmerion/src/features/reminder/presentation/screens/upcoming_reminders_screen.dart';
import 'package:tekmerion/src/features/reminder/presentation/widgets/reminder_card.dart';

class FakeReminderViewService extends ReminderViewService {
  FakeReminderViewService({
    required super.reminderRepository,
    required super.agreementRepository,
    required super.obligationRepository,
    required super.clauseRepository,
  });

  List<ReminderCardViewModel> todayViewModels = [];
  List<ReminderCardViewModel> upcomingViewModels = [];

  @override
  Future<List<ReminderCardViewModel>> getTodayViewModels(
      DateTime nowUtc, Duration gracePeriod) async {
    return todayViewModels;
  }

  @override
  Future<List<ReminderCardViewModel>> getUpcomingViewModels(
      DateTime nowUtc, Duration gracePeriod,
      {int daysHorizon = 30}) async {
    return upcomingViewModels;
  }
}

class DummyReminderRepository implements ReminderRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyAgreementRepository implements AgreementRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyObligationRepository implements ObligationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyClauseRepository implements ClauseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyReminderReconciliationService
    implements ReminderReconciliationService {
  @override
  Future<ReconciliationResult> triggerReconciliation() async {
    return const ReconciliationResult(ReconciliationResultType.completed);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeReminderViewService viewService;
  late DummyReminderReconciliationService reconciliationService;

  setUp(() {
    viewService = FakeReminderViewService(
      reminderRepository: DummyReminderRepository(),
      agreementRepository: DummyAgreementRepository(),
      obligationRepository: DummyObligationRepository(),
      clauseRepository: DummyClauseRepository(),
    );
    reconciliationService = DummyReminderReconciliationService();
  });

  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('displays loading state and then empty state', (tester) async {
    viewService.upcomingViewModels = [];

    await tester.pumpWidget(
      buildTestWidget(
        UpcomingRemindersScreen(
          viewService: viewService,
          reconciliationService: reconciliationService,
          gracePeriod: const Duration(days: 1),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('No upcoming reminders.'), findsOneWidget);
    expect(find.byType(ReminderCard), findsNothing);
  });

  testWidgets('displays reminder cards when data is available', (tester) async {
    viewService.upcomingViewModels = [
      ReminderCardViewModel(
        reminderId: 'r1',
        agreementId: 'a1',
        agreementTitle: 'Title 1',
        obligationId: 'o1',
        obligationTitle: 'Obs Upcoming',
        dueAtUtc: DateTime.utc(2026, 8, 15),
        timezone: 'UTC',
        dueAtDisplay: '2026-08-15',
        reminderState: ReminderState.scheduled,
        temporalStatus: ReminderTemporalStatus.upcoming,
        notificationStatus: NotificationSchedulingState.pending,
        canAcknowledge: true,
        canDismiss: true,
        canComplete: true,
      ),
    ];

    await tester.pumpWidget(
      buildTestWidget(
        UpcomingRemindersScreen(
          viewService: viewService,
          reconciliationService: reconciliationService,
          gracePeriod: const Duration(days: 1),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ReminderCard), findsOneWidget);
    expect(find.text('Obs Upcoming'), findsOneWidget);
  });
}
