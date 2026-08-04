enum AgreementVersionStatus {
  draft,
  active,
  superseded,
  terminated,
}

class AgreementVersion {
  const AgreementVersion({
    required this.id,
    required this.agreementId,
    required this.sourceEvidenceAssetId,
    required this.versionLabel,
    required this.status,
    required this.importedAt,
    this.effectiveFrom,
    this.effectiveTo,
    this.supersedesVersionId,
  });

  final String id;
  final String agreementId;
  final String sourceEvidenceAssetId;
  final String versionLabel;
  final AgreementVersionStatus status;
  final DateTime importedAt;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final String? supersedesVersionId;
}
