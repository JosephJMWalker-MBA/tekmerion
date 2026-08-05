import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_scheduling_state.dart';
import 'package:tekmerion/src/features/reminder/domain/reminder_state.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_card_view_model.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_temporal_status.dart';
import 'package:tekmerion/src/features/reminder/presentation/widgets/reminder_card.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  ReminderCardViewModel createViewModel({
    bool canAcknowledge = false,
    bool canDismiss = false,
    bool canComplete = false,
    ReminderTemporalStatus temporalStatus = ReminderTemporalStatus.upcoming,
  }) {
    return ReminderCardViewModel(
      reminderId: 'r1',
      agreementId: 'a1',
      agreementTitle: 'Test Agreement',
      obligationId: 'o1',
      obligationTitle: 'Test Obligation',
      clauseReference: '1.1',
      dueAtUtc: DateTime.utc(2026, 8, 1),
      timezone: 'UTC',
      dueAtDisplay: '2026-08-01 00:00:00 (UTC)',
      reminderState: ReminderState.scheduled,
      temporalStatus: temporalStatus,
      notificationStatus: NotificationSchedulingState.pending,
      canAcknowledge: canAcknowledge,
      canDismiss: canDismiss,
      canComplete: canComplete,
    );
  }

  group('ReminderCard', () {
    testWidgets('displays correctly with basic data', (tester) async {
      final viewModel = createViewModel();
      await tester
          .pumpWidget(buildTestWidget(ReminderCard(viewModel: viewModel)));

      expect(find.text('Test Obligation'), findsOneWidget);
      expect(find.text('Agreement: Test Agreement'), findsOneWidget);
      expect(find.text('Clause: 1.1'), findsOneWidget);
      expect(find.text('Due: 2026-08-01 00:00:00 (UTC)'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);

      // Actions shouldn't be visible if all flags are false
      expect(find.text('Dismiss'), findsNothing);
      expect(find.text('Acknowledge'), findsNothing);
      expect(find.text('Complete'), findsNothing);
    });

    testWidgets('displays actions based on flags', (tester) async {
      bool acknowledged = false;
      bool dismissed = false;
      bool completed = false;

      final viewModel = createViewModel(
        canAcknowledge: true,
        canDismiss: true,
        canComplete: true,
      );

      await tester.pumpWidget(
        buildTestWidget(
          ReminderCard(
            viewModel: viewModel,
            onAcknowledge: () async {
              acknowledged = true;
            },
            onDismiss: () async {
              dismissed = true;
            },
            onComplete: () {
              completed = true;
            },
          ),
        ),
      );

      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Acknowledge'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      expect(dismissed, isTrue);

      await tester.tap(find.text('Acknowledge'));
      expect(acknowledged, isTrue);

      await tester.tap(find.text('Complete'));
      expect(completed, isTrue);
    });
  });
}
