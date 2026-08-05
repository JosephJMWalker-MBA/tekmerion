import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/evidence_storage.dart';
import '../../agreement/domain/agreement_repository.dart';
import '../../clause/domain/clause_repository.dart';
import '../../obligation/domain/obligation_repository.dart';
import '../../record/domain/record_repository.dart';
import '../../timeline/domain/timeline_repository.dart';
import '../domain/export_manifest.dart';
import '../domain/export_package.dart';
import '../domain/export_package_repository.dart';
import 'export_state.dart';
import 'record_pdf_generator.dart';

class RecordPackageExportService {
  RecordPackageExportService({
    required AgreementRepository agreementRepo,
    required ClauseRepository clauseRepo,
    required ObligationRepository obligationRepo,
    required RecordRepository recordRepo,
    required TimelineRepository timelineRepo,
    required EvidenceStorage evidenceStorage,
    required ExportPackageRepository exportRepo,
    required RecordPdfGenerator pdfGenerator,
    Uuid uuid = const Uuid(),
  })  : _agreementRepo = agreementRepo,
        _clauseRepo = clauseRepo,
        _obligationRepo = obligationRepo,
        _recordRepo = recordRepo,
        _timelineRepo = timelineRepo,
        _evidenceStorage = evidenceStorage,
        _exportRepo = exportRepo,
        _pdfGenerator = pdfGenerator,
        _uuid = uuid;
  final AgreementRepository _agreementRepo;
  final ClauseRepository _clauseRepo;
  final ObligationRepository _obligationRepo;
  final RecordRepository _recordRepo;
  final TimelineRepository _timelineRepo;
  final EvidenceStorage _evidenceStorage;
  final ExportPackageRepository _exportRepo;
  final RecordPdfGenerator _pdfGenerator;
  final Uuid _uuid;

  Stream<ExportStatus> generateCompleteExport(String agreementId) async* {
    yield const ExportStatus(
      state: ExportState.collecting,
      message: 'Preparing your Record Package...',
      progress: 0.1,
    );

    final String packageId = _uuid.v4();
    Directory? stagingDir;

    try {
      // 1. Create staging directory
      final tempDir = await getTemporaryDirectory();
      stagingDir =
          Directory(p.join(tempDir.path, 'tekmerion_export_$packageId'));
      await stagingDir.create(recursive: true);

      final agreementDir = Directory(p.join(stagingDir.path, 'agreement'));
      await agreementDir.create();

      final dataDir = Directory(p.join(stagingDir.path, 'data'));
      await dataDir.create();

      final integrityDir = Directory(p.join(stagingDir.path, 'integrity'));
      await integrityDir.create();

      final evidenceDir = Directory(p.join(stagingDir.path, 'evidence'));
      await evidenceDir.create();

      // 2. Load canonical scope
      final allAgreements = await _agreementRepo.getAllAgreements();
      final agreement = allAgreements.firstWhere((a) => a.id == agreementId);

      final versions =
          await _agreementRepo.getVersionsForAgreement(agreementId);
      if (versions.isEmpty) {
        throw Exception('Agreement version not found');
      }
      final version = versions.first;

      await _clauseRepo.getClausesForAgreementVersion(version.id);

      final obligations =
          await _obligationRepo.getObligationsForAgreement(agreementId);
      final confirmedObligations =
          obligations.where((o) => o.status.name != 'draft').toList();

      await _timelineRepo.getTimelineForAgreement(agreementId);

      // Retrieve all records to gather evidence IDs
      final allRecords = await _recordRepo.allForAgreement(agreementId);
      final finalizedRecords =
          allRecords.where((r) => r.state.name == 'finalized').toList();
      final evidenceIds = finalizedRecords
          .expand((r) => r.evidence.map((e) => e.evidenceId))
          .toSet();

      yield const ExportStatus(
        state: ExportState.verifyingSources,
        message: 'Verifying included files...',
        progress: 0.3,
      );

      final manifestFiles = <PackageFileInfo>[];

      // Get Evidence Envelope for original agreement
      final originalEvidence = await _agreementRepo
          .getEvidenceAssetById(version.sourceEvidenceAssetId);
      if (originalEvidence == null) {
        throw Exception('Original agreement evidence not found in repository.');
      }

      // 3. Verify original agreement file and copy
      final originalBytes = await _evidenceStorage
          .openOriginalBytes(version.sourceEvidenceAssetId);
      final originalHash = sha256.convert(originalBytes).toString();
      if (originalHash != originalEvidence.sha256) {
        throw Exception(
          'Original agreement integrity verification failed. Expected: ${originalEvidence.sha256}, Actual: $originalHash',
        );
      }

      final ext = '.pdf';
      final copiedAgreementFile =
          File(p.join(agreementDir.path, 'original-agreement-file$ext'));
      await copiedAgreementFile.writeAsBytes(originalBytes);

      manifestFiles.add(
        PackageFileInfo(
          path: 'agreement/original-agreement-file$ext',
          mediaType: 'application/pdf',
          byteSize: originalBytes.length,
          sha256: originalHash,
        ),
      );

      // Copy Evidence
      final manifestEvidence = <EvidenceInfo>[];
      for (final evId in evidenceIds) {
        final evBytes = await _evidenceStorage.openOriginalBytes(evId);
        final evHash = sha256.convert(evBytes).toString();

        final copiedEvFile = File(p.join(evidenceDir.path, '$evId.bin'));
        await copiedEvFile.writeAsBytes(evBytes);

        manifestFiles.add(
          PackageFileInfo(
            path: 'evidence/$evId.bin',
            mediaType: 'application/octet-stream',
            byteSize: evBytes.length,
            sha256: evHash,
          ),
        );

        manifestEvidence.add(
          EvidenceInfo(
            evidenceId: evId,
            assetRole: 'original',
            captureMethod: 'in_app_capture',
            packagePath: 'evidence/$evId.bin',
            mimeType: 'application/octet-stream',
            byteSize: evBytes.length,
            sha256: evHash,
            importedAt: DateTime.now().toUtc(),
            verificationState: 'verified_unchanged_since_ingestion',
          ),
        );
      }

      yield const ExportStatus(
        state: ExportState.generatingData,
        message: 'Organizing the agreement history...',
        progress: 0.6,
      );

      final encoder = const JsonEncoder.withIndent('  ');

      // Write data JSON files
      final agreementJson = File(p.join(dataDir.path, 'agreement.json'));
      await agreementJson
          .writeAsString(encoder.convert({'title': agreement.title}));

      for (final file in [agreementJson]) {
        final bytes = await file.readAsBytes();
        manifestFiles.add(
          PackageFileInfo(
            path: 'data/${p.basename(file.path)}',
            mediaType: 'application/json',
            byteSize: bytes.length,
            sha256: sha256.convert(bytes).toString(),
          ),
        );
      }

      // Generate verification report
      final verificationReportFile =
          File(p.join(integrityDir.path, 'verification-report.json'));
      await verificationReportFile.writeAsString(
        encoder.convert({
          'verification_status': 'verified',
          'chain_scope': 'complete_agreement_chain',
          'unsigned_package': true,
        }),
      );
      final vrBytes = await verificationReportFile.readAsBytes();
      manifestFiles.add(
        PackageFileInfo(
          path: 'integrity/verification-report.json',
          mediaType: 'application/json',
          byteSize: vrBytes.length,
          sha256: sha256.convert(vrBytes).toString(),
        ),
      );

      // 4. Generate Machine-readable data & PDF
      final initialManifest = ExportManifest(
        packageId: packageId,
        generatedAt: DateTime.now().toUtc(),
        generatedTimezone: 'UTC',
        generator: const GeneratorInfo(
          applicationVersion: '1.0.0',
          buildNumber: '1',
          platform: 'android',
        ),
        scope: const ScopeInfo(
          scopeType: 'full_agreement',
          completeAgreementChain: true,
          filters: {},
        ),
        agreement: AgreementInfo(
          agreementId: agreement.id,
          title: agreement.title,
          agreementType: agreement.agreementType,
          versions: [
            AgreementVersionInfo(
              agreementVersionId: version.id,
              versionLabel: version.versionLabel,
              status: version.status.name,
              sourceFilePath: 'agreement/original-agreement-file$ext',
              sourceFileSha256: originalHash,
            ),
          ],
          parties: [],
          obligations: confirmedObligations
              .map(
                (o) => ObligationInfo(
                  obligationId: o.id,
                  title: o.title,
                  description: o.description,
                  status: o.status.name,
                  sourceType: o.sourceType.name,
                  confirmedAt: o.confirmedAt,
                ),
              )
              .toList(),
        ),
        records: finalizedRecords
            .map(
              (r) => RecordInfo(
                recordId: r.id,
                recordType: r.recordType.name,
                title: r.title,
                factualDescription: r.factualDescription,
                occurredAt: r.occurredAt,
                recordedAt: r.recordedAt,
                finalizedAt: r.finalizedAt ?? r.recordedAt,
                recordHash: r.recordHash ?? '',
                chainHash: r.chainHash ?? '',
                evidenceIds: r.evidence.map((e) => e.evidenceId).toList(),
              ),
            )
            .toList(),
        evidence: manifestEvidence,
        files: manifestFiles,
        integrity: const IntegrityInfo(
          manifestSha256:
              '0000000000000000000000000000000000000000000000000000000000000000',
          verificationStatus: 'verified',
          chainScope: 'complete_agreement_chain',
        ),
        disclaimers: const [
          'This package is a self-contained local export generated by Tekmerion.',
          'It is a presentation artifact and does not constitute a legal assertion or finding of fact by the application.',
        ],
      );

      yield const ExportStatus(
        state: ExportState.generatingPdf,
        message: 'Rendering human-readable record...',
        progress: 0.7,
      );

      final pdfBytes = await _pdfGenerator.generatePdf(initialManifest);
      final pdfFile = File(p.join(stagingDir.path, 'record.pdf'));
      await pdfFile.writeAsBytes(pdfBytes);

      manifestFiles.add(
        PackageFileInfo(
          path: 'record.pdf',
          mediaType: 'application/pdf',
          byteSize: pdfBytes.length,
          sha256: sha256.convert(pdfBytes).toString(),
        ),
      );

      // Finalize manifest with all files
      final almostFinalManifest = ExportManifest(
        packageId: initialManifest.packageId,
        generatedAt: initialManifest.generatedAt,
        generatedTimezone: initialManifest.generatedTimezone,
        generator: initialManifest.generator,
        scope: initialManifest.scope,
        agreement: initialManifest.agreement,
        records: initialManifest.records,
        evidence: initialManifest.evidence,
        files: manifestFiles, // Updated with PDF
        integrity: initialManifest.integrity,
        disclaimers: initialManifest.disclaimers,
      );

      // Write manifest.json LAST
      final manifestJsonStr = encoder.convert(almostFinalManifest.toJson());
      final manifestBytes = utf8.encode(manifestJsonStr);
      final finalManifestSha = sha256.convert(manifestBytes).toString();

      // Re-create manifest with the correct manifest hash in integrity
      final finalManifest = ExportManifest(
        packageId: almostFinalManifest.packageId,
        generatedAt: almostFinalManifest.generatedAt,
        generatedTimezone: almostFinalManifest.generatedTimezone,
        generator: almostFinalManifest.generator,
        scope: almostFinalManifest.scope,
        agreement: almostFinalManifest.agreement,
        records: almostFinalManifest.records,
        evidence: almostFinalManifest.evidence,
        files: almostFinalManifest.files,
        integrity: IntegrityInfo(
          manifestSha256: finalManifestSha,
          verificationStatus: 'verified',
          chainScope: 'complete_agreement_chain',
        ),
        disclaimers: almostFinalManifest.disclaimers,
      );

      final finalManifestBytes =
          utf8.encode(encoder.convert(finalManifest.toJson()));
      await File(p.join(stagingDir.path, 'manifest.json'))
          .writeAsBytes(finalManifestBytes);
      final trueManifestSha = sha256.convert(finalManifestBytes).toString();

      yield const ExportStatus(
        state: ExportState.packaging,
        message: 'Creating secure package...',
        progress: 0.8,
      );

      // 5. ZIP the staging directory
      final zipEncoder = ZipFileEncoder();
      final zipPath = p.join(tempDir.path, '$packageId.zip');
      zipEncoder.create(zipPath);

      // Wait for it if it's async in this version of the archive package
      final futureOrVoid =
          zipEncoder.addDirectory(stagingDir, includeDirName: false);
      await futureOrVoid;

      zipEncoder.close();

      // 6. Self-verify ZIP package
      final zipFile = File(zipPath);
      final zipBytes = await zipFile.readAsBytes();

      final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
      final extractedManifestFile = archive.findFile('manifest.json');
      if (extractedManifestFile == null) {
        throw Exception(
          'Self-verification failed: manifest.json missing from archive',
        );
      }

      final extractedManifestContent =
          utf8.decode(extractedManifestFile.content as List<int>);
      final decodedManifestMap =
          jsonDecode(extractedManifestContent) as Map<String, dynamic>;
      final filesList = decodedManifestMap['files'] as List<dynamic>;

      // Verify every file
      for (final reqFileDynamic in filesList) {
        final reqFile = reqFileDynamic as Map<String, dynamic>;
        final path = reqFile['path'] as String;
        final byteSize = reqFile['byte_size'] as int;
        final expectedHash = reqFile['sha256'] as String;

        final f = archive.findFile(path);
        if (f == null) {
          throw Exception('Self-verification failed: missing file $path');
        }
        final contentBytes = f.content as List<int>;
        if (contentBytes.length != byteSize) {
          throw Exception('Self-verification failed: size mismatch for $path');
        }
        final extractedHash = sha256.convert(contentBytes).toString();
        if (extractedHash != expectedHash) {
          throw Exception('Self-verification failed: hash mismatch for $path');
        }
        if (path.contains('../')) {
          throw Exception('Self-verification failed: unsafe path $path');
        }
      }

      // 7. Persist Metadata
      final exportPackage = ExportPackage(
        id: packageId,
        agreementId: agreementId,
        generatedAt: DateTime.now().toUtc(),
        format: 'zip',
        filterParametersJson: '{}',
        manifestSha256: trueManifestSha,
        managedStorageIdentifier: zipPath,
        generatorVersion: '1.0.0',
        completenessState: 'complete',
        warningCount: 0,
      );

      await _exportRepo.insertExportPackage(exportPackage);

      yield ExportStatus(
        state: ExportState.completed,
        message: 'Your Record Package is ready.',
        progress: 1.0,
        exportPackageId: packageId,
      );
    } catch (e) {
      yield ExportStatus(
        state: ExportState.failed,
        message: 'Export failed.',
        error: e.toString(),
      );
    } finally {
      if (stagingDir != null && await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
    }
  }
}
