import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/app.dart';
import 'package:tekmerion/src/features/agreement/application/agreement_import_service.dart';
import 'package:tekmerion/src/features/clause/domain/clause_repository.dart';
import 'package:tekmerion/src/core/storage/evidence_storage.dart';

class FakeAgreementImportService implements AgreementImportService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClauseRepository implements ClauseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeEvidenceStorage implements EvidenceStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('home screen presents the agreement-centered frozen loop',
      (WidgetTester tester) async {
    final mockImportService = FakeAgreementImportService();
    final mockClauseRepo = FakeClauseRepository();
    final mockStorage = FakeEvidenceStorage();

    await tester.pumpWidget(TekmerionApp(
      importService: mockImportService,
      clauseRepository: mockClauseRepo,
      evidenceStorage: mockStorage,
    ));

    expect(find.text('What does this agreement require now?'), findsOneWidget);
    expect(find.text('Import Lease'), findsOneWidget);
    expect(find.text('Choose your signed lease'), findsOneWidget);
  });
}
