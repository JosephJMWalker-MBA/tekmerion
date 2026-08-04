import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekmerion/src/core/database/database_schema.dart';
import 'package:tekmerion/src/core/integrity/integrity_engine.dart';
import 'package:tekmerion/src/core/storage/evidence_storage.dart';
import 'package:tekmerion/src/core/storage/local_evidence_storage.dart';
import 'package:tekmerion/src/features/agreement/application/agreement_import_service.dart';
import 'package:tekmerion/src/features/agreement/data/sqlite_agreement_repository.dart';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_repository.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_version.dart';

class MockFilePicker implements FilePickerPort {
  FileSelection? nextSelection;
  bool wasCalled = false;

  @override
  Future<FileSelection?> pickPdfFile() async {
    wasCalled = true;
    return nextSelection;
  }
}

class ThrowingAgreementRepository implements AgreementRepository {
  @override
  Future<void> importAgreementTransaction({
    required EvidenceEnvelope evidence,
    required Agreement agreement,
    required AgreementVersion version,
  }) async {
    throw Exception('Simulated DB failure');
  }

  @override
  Future<List<Agreement>> getAllAgreements() async => [];
  @override
  Future<List<AgreementVersion>> getVersionsForAgreement(String id) async => [];

  @override
  Future<EvidenceEnvelope?> getEvidenceAssetById(String evidenceId) async =>
      null;
}

void main() {
  late Directory tempDir;
  late LocalEvidenceStorage evidenceStorage;
  late Database db;
  late SqliteAgreementRepository repository;
  late MockFilePicker picker;
  late AgreementImportService service;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('tekmerion_agreement_test');

    evidenceStorage = LocalEvidenceStorage(
      getRootDirectory: () async => tempDir,
    );

    final dbPath = p.join(tempDir.path, 'test.db');
    db = await databaseFactory.openDatabase(dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('PRAGMA foreign_keys = ON');
            await db.execute(DatabaseSchema.createEvidenceAssetsTable);
            await db.execute(DatabaseSchema.createAgreementsTable);
            await db.execute(DatabaseSchema.createAgreementVersionsTable);
          },
        ));

    repository = SqliteAgreementRepository(db);
    picker = MockFilePicker();

    service = AgreementImportService(
      filePicker: picker,
      evidenceStorage: evidenceStorage,
      agreementRepository: repository,
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('picker cancellation creates nothing', () async {
    picker.nextSelection = null;
    final result = await service.importLease();
    expect(result, isNull);
    expect(picker.wasCalled, isTrue);

    final agreements = await repository.getAllAgreements();
    expect(agreements, isEmpty);
  });

  test('non-PDF rejected', () async {
    picker.nextSelection = FileSelection(
        bytes: Uint8List.fromList([1, 2, 3]), filename: 'image.jpg');
    expect(() => service.importLease(), throwsException);
  });

  test('zero-byte PDF rejected', () async {
    picker.nextSelection =
        FileSelection(bytes: Uint8List(0), filename: 'empty.pdf');
    expect(() => service.importLease(), throwsException);
  });

  test('single valid PDF successfully picked and stored', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    picker.nextSelection = FileSelection(bytes: bytes, filename: 'lease.pdf');

    final result = await service.importLease();
    expect(result, isNotNull);

    final agreements = await repository.getAllAgreements();
    expect(agreements.length, 1);
    expect(agreements.first.title, 'lease.pdf');

    final versions =
        await repository.getVersionsForAgreement(agreements.first.id);
    expect(versions.length, 1);
    expect(versions.first.sourceEvidenceAssetId, result!.evidence.evidenceId);

    final originalBytes = await evidenceStorage
        .openOriginalBytes(result.evidence.storageIdentifier);
    expect(originalBytes, bytes);
  });

  test(
      'Database insertion failure cleans up drafted evidence asset (no orphans)',
      () async {
    final failingService = AgreementImportService(
      filePicker: picker,
      evidenceStorage: evidenceStorage,
      agreementRepository: ThrowingAgreementRepository(),
    );

    picker.nextSelection = FileSelection(
        bytes: Uint8List.fromList([1, 2, 3]), filename: 'fail.pdf');

    try {
      await failingService.importLease();
      fail('Should have thrown');
    } catch (e) {
      expect(e.toString(), contains('Simulated DB failure'));
    }

    // Directory should be empty (or only the test.db)
    final files = tempDir.listSync(recursive: true);
    final pdfFiles = files.where((f) => f.path.endsWith('.pdf')).toList();
    expect(pdfFiles, isEmpty);
  });
}
