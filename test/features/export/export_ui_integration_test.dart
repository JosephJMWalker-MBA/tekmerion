import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/export/application/export_share_adapter.dart';
import 'package:tekmerion/src/features/export/application/export_state.dart';
import 'package:tekmerion/src/features/export/application/record_package_export_service.dart';
import 'package:tekmerion/src/features/export/domain/export_package.dart';
import 'package:tekmerion/src/features/export/domain/export_package_repository.dart';
import 'package:tekmerion/src/features/export/presentation/record_package_export_screen.dart';

class FakeExportService implements RecordPackageExportService {
  bool completeSuccessfully = true;
  File? tempFile;

  Stream<ExportStatus> generateCompleteExport(String agreementId) async* {
    if (completeSuccessfully) {
      yield ExportStatus(state: ExportState.collecting);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      yield ExportStatus(state: ExportState.verifyingPackage);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      yield ExportStatus(
        state: ExportState.completed,
        packageFilePath: tempFile?.path ?? '/fake/path/RecordPackage_a1.zip',
      );
    } else {
      yield ExportStatus(state: ExportState.collecting);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      throw Exception('Fake failure');
    }
  }
}

class FakeExportPackageRepository implements ExportPackageRepository {
  List<ExportPackage> packages = [];

  Future<void> savePackageMetadata(ExportPackage package) async {
    packages.add(package);
  }

  Future<void> insertExportPackage(ExportPackage package) async {
    packages.add(package);
  }

  Future<List<ExportPackage>> getPackagesForAgreement(
    String agreementId,
  ) async {
    return packages;
  }
}

class FakeExportShareAdapter implements ExportShareAdapter {
  ExportShareResult resultToReturn = ExportShareResult.shared;
  String? sharedFilePath;
  String? sharedFilename;

  Future<ExportShareResult> sharePackage({
    required String filePath,
    required String filename,
    required String mimeType,
  }) async {
    sharedFilePath = filePath;
    sharedFilename = filename;
    return resultToReturn;
  }
}

void main() {
  late FakeExportService mockExportService;
  late FakeExportPackageRepository mockExportRepo;
  late FakeExportShareAdapter mockShareAdapter;
  late File tempZip;

  setUp(() {
    tempZip = File('${Directory.systemTemp.path}/RecordPackage_a1.zip');
    tempZip.writeAsStringSync('dummy zip content');

    mockExportService = FakeExportService()..tempFile = tempZip;
    mockExportRepo = FakeExportPackageRepository();
    mockExportRepo.packages.add(
      ExportPackage(
        id: 'ep1',
        agreementId: 'a1',
        generatedAt: DateTime.now(),
        format: 'ZIP',
        filterParametersJson: '{}',
        manifestSha256:
            'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        managedStorageIdentifier: tempZip.path,
        generatorVersion: '1.0',
        completenessState: 'complete',
        warningCount: 0,
      ),
    );
    mockShareAdapter = FakeExportShareAdapter();
  });

  tearDown(() {
    if (tempZip.existsSync()) {
      tempZip.deleteSync();
    }
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: RecordPackageExportScreen(
        agreementId: 'a1',
        exportService: mockExportService,
        exportPackageRepository: mockExportRepo,
        exportShareAdapter: mockShareAdapter,
      ),
    );
  }

  group('Export UI Integration', () {
    testWidgets(
        'idle -> generating -> verifying -> completed -> explicit share',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Idle
      expect(find.text('Generate Record Package'), findsOneWidget);

      // Generating
      await tester.tap(find.text('Generate Record Package'));
      await tester.pump();
      expect(find.text('Organizing the agreement history…'), findsOneWidget);

      // Verifying
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(find.text('Verifying the completed package…'), findsOneWidget);

      // Completed
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(find.text('Your Record Package is ready.'), findsOneWidget);

      // Explicit Share
      await tester.ensureVisible(find.text('Save or Share'));
      await tester.tap(find.text('Save or Share'));
      await tester.pumpAndSettle();

      expect(
        mockShareAdapter.sharedFilePath,
        tempZip.path,
      );
    });

    testWidgets('idle -> generating -> failed -> retry -> completed',
        (WidgetTester tester) async {
      mockExportService.completeSuccessfully = false;
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Idle
      expect(find.text('Generate Record Package'), findsOneWidget);

      // Generating
      await tester.tap(find.text('Generate Record Package'));
      await tester.pump();
      expect(find.text('Organizing the agreement history…'), findsOneWidget);

      // Failed
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(
        find.text('The Record Package could not be completed.'),
        findsOneWidget,
      );

      // Retry (flip the mock)
      mockExportService.completeSuccessfully = true;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.text('Organizing the agreement history…'), findsOneWidget);

      // Completed
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(find.text('Your Record Package is ready.'), findsOneWidget);
    });
  });
}
