import 'export_package.dart';

abstract class ExportPackageRepository {
  /// Persists a successfully generated export package.
  /// Must be an append-only operation that does not overwrite prior packages.
  Future<void> insertExportPackage(ExportPackage package);

  /// Retrieves all export packages for a given agreement.
  /// Should be ordered from newest to oldest.
  Future<List<ExportPackage>> getPackagesForAgreement(String agreementId);
}
