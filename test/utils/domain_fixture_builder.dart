import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:tekmerion/src/core/storage/evidence_storage.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_repository.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_version.dart';
import 'package:tekmerion/src/features/clause/domain/clause.dart';
import 'package:tekmerion/src/features/clause/domain/clause_repository.dart';
import 'package:tekmerion/src/features/export/application/record_pdf_generator.dart';
import 'package:tekmerion/src/features/export/domain/export_manifest.dart';
import 'package:tekmerion/src/features/export/domain/export_package_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation.dart';
import 'package:tekmerion/src/features/obligation/domain/obligation_repository.dart';
import 'package:tekmerion/src/features/obligation/domain/schedule_rule.dart';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';
import 'package:tekmerion/src/features/record/domain/evidence_reference.dart';
import 'package:tekmerion/src/features/record/domain/record_entry.dart';
import 'package:tekmerion/src/features/record/domain/record_repository.dart';
import 'package:tekmerion/src/features/timeline/domain/timeline_event.dart';
import 'package:tekmerion/src/features/timeline/domain/timeline_repository.dart';

class ExportDataset {
  ExportDataset({
    required this.agreementId,
    required this.agreements,
    required this.versions,
    required this.evidence,
    required this.fileData,
    required this.clauses,
    required this.obligations,
    required this.records,
    required this.timelineEvents,
  });

  final String agreementId;
  final List<Agreement> agreements;
  final List<AgreementVersion> versions;
  final Map<String, EvidenceEnvelope> evidence;
  final Map<String, Uint8List> fileData;
  final List<Clause> clauses;
  final List<Obligation> obligations;
  final List<RecordEntry> records;
  final List<TimelineEvent> timelineEvents;
}

class DomainFixtureBuilder {
  static ExportDataset buildSyntheticExportDataset({
    int agreementMb = 0,
    int evidenceMb = 0,
    int numEvidenceFiles = 1,
  }) {
    final agreementBytes = Uint8List.fromList(
        List<int>.filled(agreementMb > 0 ? agreementMb * 1024 * 1024 : 10, 65),);
    final agHash = sha256.convert(agreementBytes).toString();

    final bytesPerEvidence =
        evidenceMb > 0 ? (evidenceMb * 1024 * 1024) ~/ numEvidenceFiles : 10;
    final evidenceBytes =
        Uint8List.fromList(List<int>.filled(bytesPerEvidence, 66));
    final evHash = sha256.convert(evidenceBytes).toString();

    final agreementId = 'a1';
    final agreement = Agreement(
      id: agreementId,
      title: 'Benchmark Agreement',
      agreementType: 'benchmark',
      status: AgreementStatus.active,
      createdAt: DateTime.now().toUtc(),
    );

    final version = AgreementVersion(
      id: 'v1',
      agreementId: agreementId,
      sourceEvidenceAssetId: 'ag_ev_1',
      versionLabel: 'v1',
      status: AgreementVersionStatus.active,
      importedAt: DateTime.now().toUtc(),
    );

    final agEnv = EvidenceEnvelope(
      evidenceId: 'ag_ev_1',
      originalFilename: 'agreement.pdf',
      mimeType: 'application/pdf',
      byteSize: agreementBytes.length,
      sha256: agHash,
      captureMethod: EvidenceCaptureMethod.externalImport,
      ingestedAt: DateTime.now().toUtc(),
      storageIdentifier: 'ag_ev_1',
      assetRole: EvidenceAssetRole.original,
    );

    final Map<String, EvidenceEnvelope> evidenceMap = {'ag_ev_1': agEnv};
    final Map<String, Uint8List> fileData = {'ag_ev_1': agreementBytes};
    final List<EvidenceReference> recEvRefs = [];

    for (int i = 0; i < numEvidenceFiles; i++) {
      final evId = 'e$i';
      final env = EvidenceEnvelope(
        evidenceId: evId,
        originalFilename: 'evidence_$i.pdf',
        mimeType: 'application/pdf',
        byteSize: evidenceBytes.length,
        sha256: evHash,
        captureMethod: EvidenceCaptureMethod.externalImport,
        ingestedAt: DateTime.now().toUtc(),
        storageIdentifier: evId,
        assetRole: EvidenceAssetRole.original,
      );
      evidenceMap[evId] = env;
      fileData[evId] = evidenceBytes;
      recEvRefs.add(EvidenceReference(
        evidenceId: env.evidenceId,
        sha256: env.sha256,
        captureMethod: env.captureMethod,
        assetRole: env.assetRole,
        bytesAvailable: true,
      ),);
    }

    final clause1 = Clause(
      id: 'c1',
      agreementVersionId: 'v1',
      sourceText: 'Test clause 1',
      pageStart: 1,
      pageEnd: 1,
      createdAt: DateTime.now().toUtc(),
      reviewState: ClauseReviewState.confirmed,
      confirmedAt: DateTime.now().toUtc(),
    );

    final obl1 = Obligation(
      id: 'o1',
      agreementId: agreementId,
      title: 'Test Obligation',
      sourceClauseId: 'c1',
      description: 'Obligation desc',
      obligationCategory: 'payment',
      createdAt: DateTime.now().toUtc(),
      sourceType: ObligationSourceType.contractual,
      status: ObligationStatus.confirmed,
      confirmedAt: DateTime.now().toUtc(),
    );

    final rec1 = RecordEntry(
      id: 'r1',
      workspaceId: 'w1',
      agreementVersionId: 'v1',
      agreementId: agreementId,
      recordType: RecordType.performance,
      title: 'Record 1',
      factualDescription: 'Performed obligation',
      occurredAt: DateTime.now().toUtc(),
      recordedAt: DateTime.now().toUtc(),
      timezone: 'UTC',
      createdByPartyId: 'p1',
      evidence: recEvRefs,
      state: RecordState.finalized,
      finalizedAt: DateTime.now().toUtc(),
      recordHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      chainHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );

    return ExportDataset(
      agreementId: agreementId,
      agreements: [agreement],
      versions: [version],
      evidence: evidenceMap,
      fileData: fileData,
      clauses: [clause1],
      obligations: [obl1],
      records: [rec1],
      timelineEvents: [],
    );
  }
}

// --- FAKES ---
class FakeAgreementRepository implements AgreementRepository {
  FakeAgreementRepository(this.agreements, this.versions, this.evidence);
  final List<Agreement> agreements;
  final List<AgreementVersion> versions;
  final Map<String, EvidenceEnvelope> evidence;

  @override
  Future<List<Agreement>> getAllAgreements() async => agreements;
  @override
  Future<List<AgreementVersion>> getVersionsForAgreement(String id) async =>
      versions;
  @override
  Future<EvidenceEnvelope?> getEvidenceAssetById(String id) async =>
      evidence[id];
  @override
  Future<void> importAgreementTransaction(
      {required EvidenceEnvelope evidence,
      required Agreement agreement,
      required AgreementVersion version,}) async {}

  // Adding getAgreementById just in case other tests need it
  @override
  Future<Agreement?> getAgreementById(String id) async {
    try {
      return agreements.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClauseRepository implements ClauseRepository {
  FakeClauseRepository(this.clauses);
  final List<Clause> clauses;
  @override
  Future<List<Clause>> getClausesForAgreementVersion(String id) async =>
      clauses;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeObligationRepository implements ObligationRepository {
  FakeObligationRepository(this.obligations);
  final List<Obligation> obligations;
  @override
  Future<List<Obligation>> getObligationsForAgreement(String id) async =>
      obligations;
  @override
  Future<ScheduleRule?> getScheduleRuleForObligation(String id) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecordRepository implements RecordRepository {
  FakeRecordRepository(this.records);
  final List<RecordEntry> records;
  @override
  Future<List<RecordEntry>> allForAgreement(String id) async => records;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTimelineRepository implements TimelineRepository {
  FakeTimelineRepository(this.events);
  final List<TimelineEvent> events;
  @override
  Future<List<TimelineEvent>> getTimelineForAgreement(String id) async =>
      events;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeEvidenceStorage implements EvidenceStorage {
  FakeEvidenceStorage(this.data);
  final Map<String, Uint8List> data;

  @override
  Future<Uint8List> openOriginalBytes(String storageIdentifier) async {
    if (!data.containsKey(storageIdentifier)) {
      throw Exception('Missing file data for $storageIdentifier');
    }
    return data[storageIdentifier]!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeExportPackageRepository implements ExportPackageRepository {
  @override
  Future<void> insertExportPackage(dynamic pkg) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecordPdfGenerator implements RecordPdfGenerator {
  @override
  Future<Uint8List> generatePdf(ExportManifest manifest) async {
    return Uint8List.fromList([1, 2, 3, 4]);
  }
}
