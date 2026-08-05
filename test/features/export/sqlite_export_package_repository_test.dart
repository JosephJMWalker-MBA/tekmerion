import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekmerion/src/core/database/database_migrations.dart';
import 'package:tekmerion/src/features/export/data/sqlite_export_package_repository.dart';
import 'package:tekmerion/src/features/export/domain/export_package.dart';

void main() {
  late Database db;
  late SqliteExportPackageRepository repo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await DatabaseMigrations.openAndMigrate(inMemoryDatabasePath);
    repo = SqliteExportPackageRepository(db);

    // Insert dummy agreement
    await db.insert('agreements', {
      'id': '11111111-1111-1111-1111-111111111111',
      'title': 'Test Agreement',
      'agreement_type': 'lease',
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
    });
  });

  tearDownAll(() async {
    await db.close();
  });

  group('SqliteExportPackageRepository', () {
    test('inserts and retrieves export package exactly', () async {
      final generatedAt = DateTime.utc(2026, 8, 4, 12, 0, 0);
      final package = ExportPackage(
        id: '77777777-7777-7777-7777-777777777777',
        agreementId: '11111111-1111-1111-1111-111111111111',
        generatedAt: generatedAt,
        format: 'zip',
        filterParametersJson: '{}',
        manifestSha256: 'deadbeef',
        managedStorageIdentifier: 'storage/pkg1.zip',
        generatorVersion: '1.0.0',
        completenessState: 'complete',
        warningCount: 0,
      );

      await repo.insertExportPackage(package);
      final retrieved = await repo
          .getPackagesForAgreement('11111111-1111-1111-1111-111111111111');

      expect(retrieved.length, 1);
      expect(retrieved.first.id, '77777777-7777-7777-7777-777777777777');
      expect(retrieved.first.manifestSha256, 'deadbeef');
      expect(retrieved.first.generatedAt, generatedAt);
    });
  });
}
