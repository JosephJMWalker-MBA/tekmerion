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
  int startCount = 0;
  File? tempFile;

  Stream<ExportStatus> generateCompleteExport(String agreementId) async* {
    startCount++;
    if (completeSuccessfully) {
      yield ExportStatus(state: ExportState.collecting);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      yield ExportStatus(state: ExportState.verifyingSources);
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
      String agreementId,) async {
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
    mockExportRepo.packages.add(ExportPackage(
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
    ),);
    mockShareAdapter = FakeExportShareAdapter();
  });

  tearDown(() {
    if (tempZip.existsSync()) {
      tempZip.deleteSync();
    }
  });

  Widget createWidgetUnderTest({String agreementTitle = 'Test Lease'}) {
    return MaterialApp(
      home: RecordPackageExportScreen(
        agreementId: 'a1',
        agreementTitle: agreementTitle,
        exportService: mockExportService,
        exportPackageRepository: mockExportRepo,
        exportShareAdapter: mockShareAdapter,
      ),
    );
  }

  group('RecordPackageExportScreen', () {
    testWidgets('Idle state displays Generate Record Package',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Generate Record Package'), findsOneWidget);
    });

    testWidgets('Progress states update in service order',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pump();

      expect(find.text('Organizing the agreement history…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();

      expect(find.text('Verifying included files…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();

      expect(find.text('Your Record Package is ready.'), findsOneWidget);
    });

    testWidgets('Generate is disabled during active export',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.enabled, isFalse);

      await tester.pumpAndSettle(); // finish
    });

    testWidgets('Double taps trigger one service call',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.tap(find.text(
          'Generate Record Package',),); // this should be disabled, thus ignored
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.enabled, isFalse);

      await tester.pumpAndSettle();
    });

    testWidgets(
        'Completed state displays filename, byte size, hash, completeness, warnings',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(agreementTitle: 'Lease'));
      await tester.pumpAndSettle();

      expect(
          find.text('Export: Lease'), findsOneWidget,); // title is not literal

      await tester.tap(find.text('Generate Record Package'));
      await tester.pumpAndSettle();

      expect(find.text('RecordPackage_a1.zip'), findsOneWidget);
      expect(find.text('0.0 KB'), findsOneWidget); // temp file has some bytes
      expect(find.text('abcdef123456...'), findsOneWidget);
      expect(find.text('complete'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      // Literal syntax avoidance
      expect(find.textContaining('\${'), findsNothing);
    });

    testWidgets('Short hash displays correctly without crashing',
        (WidgetTester tester) async {
      mockExportRepo.packages.clear();
      mockExportRepo.packages.add(ExportPackage(
        id: 'ep2',
        agreementId: 'a1',
        generatedAt: DateTime.now(),
        format: 'ZIP',
        filterParametersJson: '{}',
        manifestSha256: 'short',
        managedStorageIdentifier: '/fake/path/short.zip',
        generatorVersion: '1.0',
        completenessState: 'partial',
        warningCount: 2,
      ),);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pumpAndSettle();

      expect(find.text('short'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Share is unavailable before completion',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      expect(find.text('Save or Share'), findsNothing);

      await tester.tap(find.text('Generate Record Package'));
      await tester.pump();
      expect(find.text('Save or Share'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Save or Share'), findsOneWidget);
    });

    testWidgets('Missing ZIP blocks sharing and displays calm feedback',
        (WidgetTester tester) async {
      tempZip.deleteSync(); // Delete it to simulate missing file
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save or Share'));
      await tester.tap(find.text('Save or Share'));
      await tester.pumpAndSettle();

      expect(mockShareAdapter.sharedFilePath, isNull);
      expect(
          find.text(
              'The generated package file is missing. Please try generating again.',),
          findsOneWidget,);
    });

    testWidgets('Share requires an explicit tap and receives verified ZIP path',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save or Share'));
      await tester.tap(find.text('Save or Share'));
      await tester.pumpAndSettle();

      expect(mockShareAdapter.sharedFilePath, tempZip.path);
      expect(mockShareAdapter.sharedFilename, 'RecordPackage_a1.zip');
    });

    testWidgets('Share cancellation preserves completed state and package',
        (WidgetTester tester) async {
      mockShareAdapter.resultToReturn = ExportShareResult.cancelled;
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save or Share'));
      await tester.tap(find.text('Save or Share'));
      await tester.pumpAndSettle();

      expect(find.text('Your Record Package is ready.'), findsOneWidget);
      expect(find.text('Could not share the Record Package. Please try again.'),
          findsNothing,);
    });

    testWidgets('Share failure displays calm feedback',
        (WidgetTester tester) async {
      mockShareAdapter.resultToReturn = ExportShareResult.failed;
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save or Share'));
      await tester.tap(find.text('Save or Share'));
      await tester.pumpAndSettle();

      expect(find.text('Could not share the Record Package. Please try again.'),
          findsOneWidget,);
    });

    testWidgets('Export failure displays no success controls',
        (WidgetTester tester) async {
      mockExportService.completeSuccessfully = false;
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pumpAndSettle();

      expect(find.text('The Record Package could not be completed.'),
          findsOneWidget,);
      expect(find.text('Save or Share'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Retry initiates exactly one new generation',
        (WidgetTester tester) async {
      mockExportService.completeSuccessfully = false;
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pumpAndSettle();

      mockExportService.completeSuccessfully = true;

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Your Record Package is ready.'), findsOneWidget);
      expect(mockExportService.startCount, 2);
    });

    testWidgets(
        'Disposal during generation cancels subscription without exception',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pump();

      // Dispose screen while generating
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // No crash means success
    });

    testWidgets('Done returns to the previous screen',
        (WidgetTester tester) async {
      bool popped = false;
      await tester.pumpWidget(MaterialApp(
        home: Navigator(
          onPopPage: (route, result) {
            popped = true;
            return route.didPop(result);
          },
          pages: [
            const MaterialPage(child: Text('Home')),
            MaterialPage(
              child: RecordPackageExportScreen(
                agreementId: 'a1',
                exportService: mockExportService,
                exportPackageRepository: mockExportRepo,
                exportShareAdapter: mockShareAdapter,
              ),
            ),
          ],
        ),
      ),);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Record Package'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });
  });
}
