import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/export/application/export_state.dart';
import 'package:tekmerion/src/features/export/application/record_package_export_service.dart';

import '../../utils/domain_fixture_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
  });

  test(
    'Export completes synthetic multi-megabyte package and cleans up staging',
    () async {
      final dataset = DomainFixtureBuilder.buildSyntheticExportDataset(
        agreementMb: 1,
        evidenceMb: 4,
        numEvidenceFiles: 5,
      );

      final exportService = RecordPackageExportService(
        agreementRepo: FakeAgreementRepository(
          dataset.agreements,
          dataset.versions,
          dataset.evidence,
        ),
        clauseRepo: FakeClauseRepository(dataset.clauses),
        obligationRepo: FakeObligationRepository(dataset.obligations),
        recordRepo: FakeRecordRepository(dataset.records),
        timelineRepo: FakeTimelineRepository(dataset.timelineEvents),
        exportRepo: FakeExportPackageRepository(),
        evidenceStorage: FakeEvidenceStorage(dataset.fileData),
        pdfGenerator: FakeRecordPdfGenerator(),
      );

      ExportStatus finalStatus = const ExportStatus();
      final stream = exportService.generateCompleteExport(dataset.agreementId);
      await for (final status in stream) {
        finalStatus = status;
      }

      expect(finalStatus.state, ExportState.completed);

      final zipFile = File(finalStatus.packageFilePath!);
      expect(zipFile.existsSync(), isTrue);
      expect(zipFile.lengthSync(), greaterThan(0));

      final stagingDir = Directory(
        '${Directory.systemTemp.path}/_export_staging_${dataset.agreementId}',
      );
      expect(
        stagingDir.existsSync(),
        isFalse,
        reason: 'Staging directory must be cleaned up on success',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
