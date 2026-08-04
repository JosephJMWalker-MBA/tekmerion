import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation.dart';
import 'package:tekmerion/src/features/record/application/complete_obligation_service.dart';
import 'package:tekmerion/src/features/record/domain/record_entry.dart';
import 'package:tekmerion/src/features/record/presentation/complete_obligation_screen.dart';

class MockCompleteObligationService implements CompleteObligationService {
  bool completeCalled = false;
  String? noteParam;
  bool? pickEvidenceParam;

  @override
  Future<CompleteObligationResult?> completeObligation({
    required String obligationId,
    required String agreementVersionId,
    required String note,
    required DateTime occurredAt,
    required bool pickEvidence,
    void Function(String state)? onStateChange,
  }) async {
    completeCalled = true;
    noteParam = note;
    pickEvidenceParam = pickEvidence;

    onStateChange?.call('completed');

    return CompleteObligationResult(
      recordEntry: RecordEntry(
        id: 'r1',
        workspaceId: 'w1',
        agreementId: 'a1',
        agreementVersionId: 'v1',
        recordType: RecordType.performance,
        title: 'Title',
        factualDescription: note,
        occurredAt: occurredAt,
        recordedAt: DateTime.now(),
        timezone: 'UTC',
        createdByPartyId: 'self',
        state: RecordState.finalized,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final obligation = Obligation(
    id: 'o1',
    agreementId: 'a1',
    sourceType: ObligationSourceType.contractual,
    title: 'Pay Rent',
    description: 'Pay \$1000',
    obligationCategory: 'payment',
    status: ObligationStatus.confirmed,
    createdAt: DateTime.now(),
  );

  testWidgets('CompleteObligationScreen calls service on submit',
      (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1080, 2400);
    tester.binding.window.devicePixelRatioTestValue = 3.0;

    final mockService = MockCompleteObligationService();

    await tester.pumpWidget(
      MaterialApp(
        home: CompleteObligationScreen(
          obligation: obligation,
          agreementVersionId: 'v1',
          service: mockService,
        ),
      ),
    );

    expect(find.text('Complete Obligation'), findsOneWidget);
    expect(find.text('Title: Pay Rent'), findsOneWidget);
    expect(find.text('Description: Pay \$1000'), findsOneWidget);

    // Enter note
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Optional Note / Factual Description'),
      'Paid via transfer',
    );
    await tester.pump();

    // Toggle evidence
    await tester
        .tap(find.widgetWithText(SwitchListTile, 'Attach Receipt/Document'));
    await tester.pumpAndSettle();

    // Submit
    await tester
        .tap(find.widgetWithText(FilledButton, 'Complete & Finalize Record'));
    await tester.pumpAndSettle();

    expect(mockService.completeCalled, isTrue);
    expect(mockService.noteParam, 'Paid via transfer');
    expect(mockService.pickEvidenceParam, isTrue);

    // Should pop
    expect(find.text('Complete Obligation'), findsNothing);

    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
  });
}
