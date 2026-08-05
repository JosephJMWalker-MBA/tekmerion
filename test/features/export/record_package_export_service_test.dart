import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/export/application/export_state.dart';
import 'package:tekmerion/src/features/export/application/record_package_export_service.dart';

import '../../utils/domain_fixture_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'RecordPackageExportService completes package generation and self-verification',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('export_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    final dataset = DomainFixtureBuilder.buildSyntheticExportDataset(
      agreementMb: 0, // tiny for fast test
      evidenceMb: 0,
      numEvidenceFiles: 1,
    );

    final service = RecordPackageExportService(
      agreementRepo: FakeAgreementRepository(
        dataset.agreements,
        dataset.versions,
        dataset.evidence,
      ),
      clauseRepo: FakeClauseRepository(dataset.clauses),
      obligationRepo: FakeObligationRepository(dataset.obligations),
      recordRepo: FakeRecordRepository(dataset.records),
      timelineRepo: FakeTimelineRepository(dataset.timelineEvents),
      evidenceStorage: FakeEvidenceStorage(dataset.fileData),
      exportRepo: FakeExportPackageRepository(),
      pdfGenerator: FakeRecordPdfGenerator(),
    );

    final statuses =
        await service.generateCompleteExport(dataset.agreementId).toList();
    expect(statuses.last.state, ExportState.completed);
  });
}
