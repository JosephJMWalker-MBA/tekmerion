import 'package:sqflite/sqflite.dart';
import '../domain/export_package.dart';
import '../domain/export_package_repository.dart';

class SqliteExportPackageRepository implements ExportPackageRepository {
  const SqliteExportPackageRepository(this._db);
  final Database _db;

  @override
  Future<void> insertExportPackage(ExportPackage package) async {
    await _db.insert(
      'export_packages',
      package.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail, // Append-only, never overwrite
    );
  }

  @override
  Future<List<ExportPackage>> getPackagesForAgreement(
    String agreementId,
  ) async {
    final rows = await _db.query(
      'export_packages',
      where: 'agreement_id = ?',
      whereArgs: [agreementId],
      orderBy: 'generated_at DESC',
    );

    return rows.map((row) => ExportPackage.fromMap(row)).toList();
  }
}
