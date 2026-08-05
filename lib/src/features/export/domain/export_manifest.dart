import 'package:meta/meta.dart';

@immutable
class ExportManifest {
  const ExportManifest({
    required this.packageId,
    required this.generatedAt,
    required this.generatedTimezone,
    required this.generator,
    required this.scope,
    required this.agreement,
    required this.records,
    required this.evidence,
    required this.files,
    required this.integrity,
    required this.disclaimers,
  });
  final String packageId;
  final DateTime generatedAt;
  final String generatedTimezone;
  final GeneratorInfo generator;
  final ScopeInfo scope;
  final AgreementInfo agreement;
  final List<RecordInfo> records;
  final List<EvidenceInfo> evidence;
  final List<PackageFileInfo> files;
  final IntegrityInfo integrity;
  final List<String> disclaimers;

  Map<String, dynamic> toJson() {
    return {
      'schema_version': '1.0.0',
      'package_id': packageId,
      'generated_at': generatedAt.toUtc().toIso8601String(),
      'generated_timezone': generatedTimezone,
      'generator': generator.toJson(),
      'scope': scope.toJson(),
      'agreement': agreement.toJson(),
      'records': records.map((e) => e.toJson()).toList(),
      'evidence': evidence.map((e) => e.toJson()).toList(),
      'files': files.map((e) => e.toJson()).toList(),
      'integrity': integrity.toJson(),
      'disclaimers': disclaimers,
    };
  }
}

@immutable
class GeneratorInfo {
  const GeneratorInfo({
    required this.applicationVersion,
    required this.buildNumber,
    required this.platform,
  });
  final String applicationVersion;
  final String buildNumber;
  final String platform;

  Map<String, dynamic> toJson() {
    return {
      'application': 'Tekmerion',
      'application_version': applicationVersion,
      'build_number': buildNumber,
      'platform': platform,
      'package_identifier': 'com.aerialsoft.tekmerion',
    };
  }
}

@immutable
class ScopeInfo {
  const ScopeInfo({
    required this.scopeType,
    required this.completeAgreementChain,
    required this.filters,
    this.excludedItemCount,
    this.completenessWarnings = const [],
  });
  final String scopeType;
  final bool completeAgreementChain;
  final Map<String, dynamic> filters;
  final int? excludedItemCount;
  final List<String> completenessWarnings;

  Map<String, dynamic> toJson() {
    return {
      'scope_type': scopeType,
      'complete_agreement_chain': completeAgreementChain,
      'filters': filters,
      if (excludedItemCount != null) 'excluded_item_count': excludedItemCount,
      if (completenessWarnings.isNotEmpty)
        'completeness_warnings': completenessWarnings,
    };
  }
}

@immutable
class AgreementInfo {
  const AgreementInfo({
    required this.agreementId,
    required this.title,
    required this.agreementType,
    this.subjectId,
    this.lifecycleStage,
    required this.versions,
    required this.parties,
    required this.obligations,
  });
  final String agreementId;
  final String title;
  final String agreementType;
  final String? subjectId;
  final String? lifecycleStage;
  final List<AgreementVersionInfo> versions;
  final List<PartyInfo> parties;
  final List<ObligationInfo> obligations;

  Map<String, dynamic> toJson() {
    return {
      'agreement_id': agreementId,
      'title': title,
      'agreement_type': agreementType,
      if (subjectId != null) 'subject_id': subjectId,
      if (lifecycleStage != null) 'lifecycle_stage': lifecycleStage,
      'versions': versions.map((e) => e.toJson()).toList(),
      'parties': parties.map((e) => e.toJson()).toList(),
      'obligations': obligations.map((e) => e.toJson()).toList(),
    };
  }
}

@immutable
class PartyInfo {
  const PartyInfo({
    required this.partyId,
    required this.displayName,
    this.partyType,
    required this.roles,
  });
  final String partyId;
  final String displayName;
  final String? partyType;
  final List<String> roles;

  Map<String, dynamic> toJson() {
    return {
      'party_id': partyId,
      'display_name': displayName,
      if (partyType != null) 'party_type': partyType,
      'roles': roles,
    };
  }
}

@immutable
class AgreementVersionInfo {
  const AgreementVersionInfo({
    required this.agreementVersionId,
    required this.versionLabel,
    required this.status,
    this.effectiveFrom,
    this.effectiveTo,
    required this.sourceFilePath,
    required this.sourceFileSha256,
  });
  final String agreementVersionId;
  final String versionLabel;
  final String status;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final String sourceFilePath;
  final String sourceFileSha256;

  Map<String, dynamic> toJson() {
    return {
      'agreement_version_id': agreementVersionId,
      'version_label': versionLabel,
      'status': status,
      if (effectiveFrom != null)
        'effective_from': effectiveFrom!.toUtc().toIso8601String(),
      if (effectiveTo != null)
        'effective_to': effectiveTo!.toUtc().toIso8601String(),
      'source_file_path': sourceFilePath,
      'source_file_sha256': sourceFileSha256,
    };
  }
}

@immutable
class ObligationInfo {
  const ObligationInfo({
    required this.obligationId,
    required this.title,
    required this.description,
    required this.status,
    required this.sourceType,
    this.responsiblePartyId,
    this.benefitedPartyId,
    this.confirmedAt,
    this.sourceClause,
  });
  final String obligationId;
  final String title;
  final String description;
  final String status;
  final String sourceType;
  final String? responsiblePartyId;
  final String? benefitedPartyId;
  final DateTime? confirmedAt;
  final ClauseReferenceInfo? sourceClause;

  Map<String, dynamic> toJson() {
    return {
      'obligation_id': obligationId,
      'title': title,
      'description': description,
      'status': status,
      'source_type': sourceType,
      if (responsiblePartyId != null)
        'responsible_party_id': responsiblePartyId,
      if (benefitedPartyId != null) 'benefited_party_id': benefitedPartyId,
      if (confirmedAt != null)
        'confirmed_at': confirmedAt!.toUtc().toIso8601String(),
      'source_clause': sourceClause?.toJson(),
    };
  }
}

@immutable
class ClauseReferenceInfo {
  const ClauseReferenceInfo({
    required this.agreementVersionId,
    required this.clauseId,
    this.clauseNumber,
    this.heading,
    this.pageStart,
    this.pageEnd,
    required this.sourceText,
  });
  final String agreementVersionId;
  final String clauseId;
  final String? clauseNumber;
  final String? heading;
  final int? pageStart;
  final int? pageEnd;
  final String sourceText;

  Map<String, dynamic> toJson() {
    return {
      'agreement_version_id': agreementVersionId,
      'clause_id': clauseId,
      if (clauseNumber != null) 'clause_number': clauseNumber,
      if (heading != null) 'heading': heading,
      if (pageStart != null) 'page_start': pageStart,
      if (pageEnd != null) 'page_end': pageEnd,
      'source_text': sourceText,
    };
  }
}

@immutable
class RecordInfo {
  const RecordInfo({
    required this.recordId,
    required this.recordType,
    required this.title,
    required this.factualDescription,
    this.interpretationText,
    required this.occurredAt,
    required this.recordedAt,
    required this.finalizedAt,
    this.timezone,
    this.obligationId,
    this.sourceClause,
    this.correctsRecordId,
    required this.recordHash,
    this.previousChainHash,
    required this.chainHash,
    required this.evidenceIds,
  });
  final String recordId;
  final String recordType;
  final String title;
  final String factualDescription;
  final String? interpretationText;
  final DateTime occurredAt;
  final DateTime recordedAt;
  final DateTime finalizedAt;
  final String? timezone;
  final String? obligationId;
  final ClauseReferenceInfo? sourceClause;
  final String? correctsRecordId;
  final String recordHash;
  final String? previousChainHash;
  final String chainHash;
  final List<String> evidenceIds;

  Map<String, dynamic> toJson() {
    return {
      'record_id': recordId,
      'record_type': recordType,
      'title': title,
      'factual_description': factualDescription,
      if (interpretationText != null) 'interpretation_text': interpretationText,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'finalized_at': finalizedAt.toUtc().toIso8601String(),
      if (timezone != null) 'timezone': timezone,
      if (obligationId != null) 'obligation_id': obligationId,
      if (sourceClause != null) 'source_clause': sourceClause!.toJson(),
      if (correctsRecordId != null) 'corrects_record_id': correctsRecordId,
      'record_hash': recordHash,
      if (previousChainHash != null) 'previous_chain_hash': previousChainHash,
      'chain_hash': chainHash,
      'evidence_ids': evidenceIds,
    };
  }
}

@immutable
class EvidenceInfo {
  const EvidenceInfo({
    required this.evidenceId,
    required this.assetRole,
    this.derivedFromEvidenceId,
    required this.captureMethod,
    required this.packagePath,
    this.originalFilename,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    this.capturedAt,
    required this.importedAt,
    required this.verificationState,
    this.preIngestionHistoryKnown,
    this.sourceMetadata,
  });
  final String evidenceId;
  final String assetRole;
  final String? derivedFromEvidenceId;
  final String captureMethod;
  final String packagePath;
  final String? originalFilename;
  final String mimeType;
  final int byteSize;
  final String sha256;
  final DateTime? capturedAt;
  final DateTime importedAt;
  final String verificationState;
  final bool? preIngestionHistoryKnown;
  final Map<String, dynamic>? sourceMetadata;

  Map<String, dynamic> toJson() {
    return {
      'evidence_id': evidenceId,
      'asset_role': assetRole,
      if (derivedFromEvidenceId != null)
        'derived_from_evidence_id': derivedFromEvidenceId,
      'capture_method': captureMethod,
      'package_path': packagePath,
      if (originalFilename != null) 'original_filename': originalFilename,
      'mime_type': mimeType,
      'byte_size': byteSize,
      'sha256': sha256,
      if (capturedAt != null)
        'captured_at': capturedAt!.toUtc().toIso8601String(),
      'imported_at': importedAt.toUtc().toIso8601String(),
      'verification_state': verificationState,
      if (preIngestionHistoryKnown != null)
        'pre_ingestion_history_known': preIngestionHistoryKnown,
      if (sourceMetadata != null) 'source_metadata': sourceMetadata,
    };
  }
}

@immutable
class PackageFileInfo {
  const PackageFileInfo({
    required this.path,
    required this.mediaType,
    required this.byteSize,
    required this.sha256,
  });
  final String path;
  final String mediaType;
  final int byteSize;
  final String sha256;

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'media_type': mediaType,
      'byte_size': byteSize,
      'sha256': sha256,
    };
  }
}

@immutable
class IntegrityInfo {
  const IntegrityInfo({
    required this.manifestSha256,
    this.manifestSignaturePath,
    required this.verificationStatus,
    required this.chainScope,
    this.verificationReportPath,
  });
  final String manifestSha256;
  final String? manifestSignaturePath;
  final String verificationStatus;
  final String chainScope;
  final String? verificationReportPath;

  Map<String, dynamic> toJson() {
    return {
      'manifest_sha256': manifestSha256,
      if (manifestSignaturePath != null)
        'manifest_signature_path': manifestSignaturePath,
      'verification_status': verificationStatus,
      'chain_scope': chainScope,
      if (verificationReportPath != null)
        'verification_report_path': verificationReportPath,
    };
  }
}
