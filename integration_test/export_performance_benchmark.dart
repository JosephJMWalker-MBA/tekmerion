import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tekmerion/src/features/export/application/export_state.dart';
import 'package:tekmerion/src/features/export/application/record_package_export_service.dart';

import '../test/utils/domain_fixture_builder.dart';

Future<void> runBenchmark(
  String name, {
  required int agreementMb,
  required int evidenceMb,
}) async {
  debugPrint(
    '\n--- Running $name Benchmark ($agreementMb MB Agreement, $evidenceMb MB Evidence) ---',
  );
  final stopwatch = Stopwatch()..start();

  final dataset = DomainFixtureBuilder.buildSyntheticExportDataset(
    agreementMb: agreementMb,
    evidenceMb: evidenceMb,
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

  int maxRss = 0;
  ExportStatus finalStatus = const ExportStatus();

  final stream = exportService.generateCompleteExport(dataset.agreementId);
  await for (final status in stream) {
    final rss = ProcessInfo.currentRss;
    if (rss > maxRss) maxRss = rss;
    finalStatus = status;
  }

  if (finalStatus.state != ExportState.completed) {
    throw Exception(
      'Benchmark $name failed with state ${finalStatus.state.name}: ${finalStatus.error}',
    );
  }

  stopwatch.stop();
  final zipFile = File(finalStatus.packageFilePath!);
  final sizeBytes = await zipFile.length();

  debugPrint('  Result: SUCCESS');
  debugPrint('  Total Time: ${stopwatch.elapsedMilliseconds} ms');
  debugPrint(
      '  ZIP Size: ${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
  debugPrint(
    '  Peak RSS (approx): ${(maxRss / (1024 * 1024)).toStringAsFixed(2)} MB',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Run Small Benchmark', (WidgetTester tester) async {
    await runBenchmark('Small', agreementMb: 1, evidenceMb: 4);
  });

  testWidgets('Run Medium Benchmark', (WidgetTester tester) async {
    await runBenchmark('Medium', agreementMb: 10, evidenceMb: 40);
  });

  testWidgets('Run Large Benchmark', (WidgetTester tester) async {
    await runBenchmark('Large', agreementMb: 20, evidenceMb: 80);
  });
}
