import 'package:sqflite/sqflite.dart';
import '../../record/domain/evidence_envelope.dart';
import '../../record/domain/evidence_reference.dart';
import '../domain/agreement.dart';
import '../domain/agreement_repository.dart';
import '../domain/agreement_version.dart';

class SqliteAgreementRepository implements AgreementRepository {
  SqliteAgreementRepository(this._db);

  final Database _db;

  @override
  Future<void> importAgreementTransaction({
    required EvidenceEnvelope evidence,
    required Agreement agreement,
    required AgreementVersion version,
  }) async {
    await _db.transaction((txn) async {
      // 1. Insert evidence metadata
      await txn.insert('evidence_assets', {
        'id': evidence.evidenceId,
        'original_filename': evidence.originalFilename,
        'sanitized_storage_filename': evidence.storageIdentifier,
        'mime_type': evidence.mimeType,
        'byte_size': evidence.byteSize,
        'sha256': evidence.sha256,
        'managed_storage_identifier': evidence.storageIdentifier,
        'capture_method': evidence.captureMethod.name,
        'asset_role': evidence.assetRole.name,
        'imported_at': DateTime.now().toUtc().toIso8601String(),
        'captured_at': DateTime.now().toUtc().toIso8601String(),
        'pre_ingestion_history_status': 'unknown',
        'deletion_state': 'active',
      });

      // 2. Insert agreement
      await txn.insert('agreements', {
        'id': agreement.id,
        'title': agreement.title,
        'agreement_type': agreement.agreementType,
        'status': agreement.status.name,
        'created_at': agreement.createdAt.toIso8601String(),
        if (agreement.archivedAt != null)
          'archived_at': agreement.archivedAt!.toIso8601String(),
      });

      // 3. Insert agreement version
      await txn.insert('agreement_versions', {
        'id': version.id,
        'agreement_id': version.agreementId,
        'source_evidence_asset_id': version.sourceEvidenceAssetId,
        'version_label': version.versionLabel,
        'status': version.status.name,
        'imported_at': version.importedAt.toIso8601String(),
        if (version.effectiveFrom != null)
          'effective_from': version.effectiveFrom!.toIso8601String(),
        if (version.effectiveTo != null)
          'effective_to': version.effectiveTo!.toIso8601String(),
        if (version.supersedesVersionId != null)
          'supersedes_version_id': version.supersedesVersionId,
      });
    });
  }

  @override
  Future<List<Agreement>> getAllAgreements() async {
    final rows = await _db.query('agreements', orderBy: 'created_at DESC');
    return rows.map((row) {
      return Agreement(
        id: row['id'] as String,
        title: row['title'] as String,
        agreementType: row['agreement_type'] as String,
        status:
            AgreementStatus.values.firstWhere((e) => e.name == row['status']),
        createdAt: DateTime.parse(row['created_at'] as String),
        archivedAt: row['archived_at'] != null
            ? DateTime.parse(row['archived_at'] as String)
            : null,
      );
    }).toList();
  }

  @override
  Future<List<AgreementVersion>> getVersionsForAgreement(
      String agreementId) async {
    final rows = await _db.query(
      'agreement_versions',
      where: 'agreement_id = ?',
      whereArgs: [agreementId],
      orderBy: 'imported_at DESC',
    );
    return rows.map((row) {
      return AgreementVersion(
        id: row['id'] as String,
        agreementId: row['agreement_id'] as String,
        sourceEvidenceAssetId: row['source_evidence_asset_id'] as String,
        versionLabel: row['version_label'] as String,
        status: AgreementVersionStatus.values
            .firstWhere((e) => e.name == row['status']),
        importedAt: DateTime.parse(row['imported_at'] as String),
        effectiveFrom: row['effective_from'] != null
            ? DateTime.parse(row['effective_from'] as String)
            : null,
        effectiveTo: row['effective_to'] != null
            ? DateTime.parse(row['effective_to'] as String)
            : null,
        supersedesVersionId: row['supersedes_version_id'] as String?,
      );
    }).toList();
  }

  @override
  Future<EvidenceEnvelope?> getEvidenceAssetById(String evidenceId) async {
    final rows = await _db.query(
      'evidence_assets',
      where: 'id = ?',
      whereArgs: [evidenceId],
    );

    if (rows.isEmpty) return null;
    final row = rows.first;

    return EvidenceEnvelope(
      evidenceId: row['id'] as String,
      originalFilename: row['original_filename'] as String,
      mimeType: row['mime_type'] as String,
      byteSize: row['byte_size'] as int,
      sha256: row['sha256'] as String,
      captureMethod: EvidenceCaptureMethod.values
          .firstWhere((e) => e.name == row['capture_method']),
      ingestedAt: DateTime.parse(row['imported_at'] as String),
      storageIdentifier: row['managed_storage_identifier'] as String,
      assetRole: EvidenceAssetRole.values
          .firstWhere((e) => e.name == row['asset_role']),
      derivedFromEvidenceId: row['derived_from_evidence_id'] as String?,
    );
  }
}
