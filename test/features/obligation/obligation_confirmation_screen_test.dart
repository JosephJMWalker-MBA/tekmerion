import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_version.dart';
import 'package:tekmerion/src/features/clause/domain/clause.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/schedule_rule.dart';
import 'package:tekmerion/src/features/obligation/presentation/obligation_confirmation_screen.dart';

class MockObligationRepository implements ObligationRepository {
  final List<Obligation> createdObligations = [];
  final List<ScheduleRule> createdRules = [];

  @override
  Future<void> createDraftObligation(Obligation obligation) async {
    createdObligations.add(obligation);
  }

  @override
  Future<void> confirmObligation(String obligationId) async {
    final idx = createdObligations.indexWhere((o) => o.id == obligationId);
    if (idx != -1) {
      createdObligations[idx] = createdObligations[idx].copyWith(
        status: ObligationStatus.confirmed,
        confirmedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> createScheduleRule(ScheduleRule rule) async {
    createdRules.add(rule);
  }

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

  final version = AgreementVersion(
    id: 'v1',
    agreementId: 'a1',
    sourceEvidenceAssetId: 'e1',
    versionLabel: 'v1',
    status: AgreementVersionStatus.active,
    importedAt: DateTime.now(),
  );

  final clause = Clause(
    id: 'c1',
    agreementVersionId: 'v1',
    sourceText: 'Tenant must pay rent.',
    pageStart: 1,
    pageEnd: 1,
    reviewState: ClauseReviewState.confirmed,
    createdAt: DateTime.now(),
    confirmedAt: DateTime.now(),
  );

  testWidgets('ObligationConfirmationScreen validates and saves obligation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    final mockRepo = MockObligationRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ObligationConfirmationScreen(
          agreement: agreement,
          version: version,
          clause: clause,
          repository: mockRepo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial layout
    expect(find.text('Tenant must pay rent.'), findsOneWidget);
    expect(find.text('Define Obligation'), findsOneWidget);

    // Try to continue without title/description
    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);

    // Enter details
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Pay Rent',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Factual Description'),
      'Monthly rent payment',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Responsible Party'),
      'Tenant',
    );

    // Continue to Review step
    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsOneWidget);
    expect(find.text('Pay Rent'), findsWidgets); // Should appear in review row

    // Submit (Confirm)
    await tester.tap(find.text('Continue').hitTestable());
    await tester.pumpAndSettle();

    // Verify it was saved and confirmed
    expect(mockRepo.createdObligations.length, equals(1));
    expect(mockRepo.createdObligations.first.title, equals('Pay Rent'));
    expect(
      mockRepo.createdObligations.first.status,
      equals(ObligationStatus.confirmed),
    );
  });
}
