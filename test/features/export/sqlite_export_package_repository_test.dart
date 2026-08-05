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
      'id': 'a1',
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
        id: 'pkg1',
        agreementId: 'a1',
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
      final retrieved = await repo.getPackagesForAgreement('a1');

      expect(retrieved.length, 1);
      expect(retrieved.first.id, 'pkg1');
      expect(retrieved.first.manifestSha256, 'deadbeef');
      expect(retrieved.first.generatedAt, generatedAt);
    });
  });
}
