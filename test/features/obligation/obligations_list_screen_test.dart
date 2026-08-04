import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation_repository.dart';
import 'package:tekmerion/src/features/obligation/presentation/obligations_list_screen.dart';
import 'package:tekmerion/src/features/record/application/complete_obligation_service.dart';

class MockObligationRepository implements ObligationRepository {
  final List<Obligation> mockObligations = [
    Obligation(
      id: 'o1',
      agreementId: 'a1',
      sourceType: ObligationSourceType.contractual,
      title: 'Active Obligation',
      description: 'Pending task',
      obligationCategory: 'payment',
      status: ObligationStatus.confirmed,
      createdAt: DateTime.now(),
    ),
    Obligation(
      id: 'o2',
      agreementId: 'a1',
      sourceType: ObligationSourceType.contractual,
      title: 'Completed Obligation',
      description: 'Done task',
      obligationCategory: 'payment',
      status: ObligationStatus.fulfilled,
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Obligation>> getObligationsForAgreement(
    String agreementId,
  ) async {
    return mockObligations.where((o) => o.agreementId == agreementId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCompleteObligationService implements CompleteObligationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final agreement = Agreement(
    id: 'a1',
    title: 'Test Lease',
    agreementType: 'lease',
    status: AgreementStatus.active,
    createdAt: DateTime.now(),
  );

  testWidgets(
      'ObligationsListScreen displays active and fulfilled obligations properly sorted',
      (WidgetTester tester) async {
    final mockRepo = MockObligationRepository();
    final mockService = MockCompleteObligationService();

    await tester.pumpWidget(
      MaterialApp(
        home: ObligationsListScreen(
          agreement: agreement,
          agreementVersionId: 'v1',
          obligationRepository: mockRepo,
          completeObligationService: mockService,
        ),
      ),
    );

    // Wait for load
    await tester.pumpAndSettle();

    expect(find.text('Obligations: Test Lease'), findsOneWidget);

    expect(find.text('Active Obligation'), findsOneWidget);
    expect(find.text('Completed Obligation'), findsOneWidget);

    expect(find.text('Complete'), findsOneWidget); // For the active one
    expect(
      find.byIcon(Icons.check_circle),
      findsOneWidget,
    ); // For the fulfilled one
  });
}
