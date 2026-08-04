enum EvidenceCaptureMethod {
  inAppCapture,
  externalImport,
}

enum EvidenceAssetRole {
  original,
  preview,
  redactedCopy,
  annotatedCopy,
}

class EvidenceReference {
  const EvidenceReference({
    required this.evidenceId,
    required this.sha256,
    required this.captureMethod,
    required this.assetRole,
    required this.bytesAvailable,
  });

  final String evidenceId;
  final String sha256;
  final EvidenceCaptureMethod captureMethod;
  final EvidenceAssetRole assetRole;
  final bool bytesAvailable;

  bool get hasValidSha256 {
    final RegExp pattern = RegExp(r'^[a-f0-9]{64}$');
    return pattern.hasMatch(sha256);
  }
}
