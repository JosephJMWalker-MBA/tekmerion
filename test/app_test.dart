import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/app.dart';
import 'package:tekmerion/src/core/storage/evidence_storage.dart';
import 'package:tekmerion/src/features/agreement/application/agreement_import_service.dart';
import 'package:tekmerion/src/features/clause/domain/clause_repository.dart';
import 'package:tekmerion/src/features/export/application/export_share_adapter.dart';
import 'package:tekmerion/src/features/export/application/record_package_export_service.dart';
import 'package:tekmerion/src/features/export/domain/export_package_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation_repository.dart';
import 'package:tekmerion/src/features/record/application/complete_obligation_service.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_view_service.dart';
import 'package:tekmerion/src/features/timeline/application/agreement_timeline_service.dart';

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

class FakeCompleteObligationService implements CompleteObligationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAgreementTimelineService implements AgreementTimelineService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeObligationRepository implements ObligationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecordPackageExportService implements RecordPackageExportService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeExportPackageRepository implements ExportPackageRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeExportShareAdapter implements ExportShareAdapter {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReminderViewService implements ReminderViewService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('home screen presents the agreement-centered frozen loop',
      (WidgetTester tester) async {
    final mockImportService = FakeAgreementImportService();
    final mockClauseRepo = FakeClauseRepository();
    final mockStorage = FakeEvidenceStorage();
    final mockCompleteObligationService = FakeCompleteObligationService();
    final mockTimelineService = FakeAgreementTimelineService();
    final mockObligationRepo = FakeObligationRepository();
    final mockExportService = FakeRecordPackageExportService();
    final mockExportRepo = FakeExportPackageRepository();
    final mockExportShareAdapter = FakeExportShareAdapter();
    final mockReminderViewService = FakeReminderViewService();

    await tester.pumpWidget(
      TekmerionApp(
        importService: mockImportService,
        clauseRepository: mockClauseRepo,
        obligationRepository: mockObligationRepo,
        evidenceStorage: mockStorage,
        completeObligationService: mockCompleteObligationService,
        timelineService: mockTimelineService,
        exportService: mockExportService,
        exportPackageRepository: mockExportRepo,
        exportShareAdapter: mockExportShareAdapter,
        reminderViewService: mockReminderViewService,
      ),
    );

    expect(find.text('What does this agreement require now?'), findsOneWidget);
    expect(find.text('Import Lease'), findsOneWidget);
    expect(find.text('Choose your signed lease'), findsOneWidget);
  });
}
