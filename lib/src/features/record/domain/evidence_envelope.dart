import 'package:tekmerion/src/features/record/domain/evidence_reference.dart';

/// Represents a durably stored evidence asset.
class EvidenceEnvelope {
  const EvidenceEnvelope({
    required this.evidenceId,
    required this.originalFilename,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    required this.captureMethod,
    required this.ingestedAt,
    required this.storageIdentifier,
    required this.assetRole,
    this.derivedFromEvidenceId,
  });

  final String evidenceId;
  final String originalFilename;
  final String mimeType;
  final int byteSize;
  final String sha256;
  final EvidenceCaptureMethod captureMethod;
  final DateTime ingestedAt;
  final String storageIdentifier;
  final EvidenceAssetRole assetRole;
  final String? derivedFromEvidenceId;
}
