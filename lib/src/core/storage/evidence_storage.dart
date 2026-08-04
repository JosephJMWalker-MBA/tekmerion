import 'dart:typed_data';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';

enum EvidenceVerificationState {
  verifiedUnchangedSinceIngestion,
  missing,
  hashMismatch,
  byteSizeMismatch,
  unreadable,
}

abstract interface class EvidenceStorage {
  /// Ingests an external file by copying it into managed app-private storage
  /// and calculating its SHA-256 digest.
  Future<EvidenceEnvelope> ingestExternalFile({
    required String sourceFilePath,
    required String originalFilename,
    required String mimeType,
    String? derivedFromEvidenceId,
  });

  /// Ingests raw bytes captured within the application (e.g. from the camera)
  /// into managed app-private storage.
  Future<EvidenceEnvelope> ingestCapturedBytes({
    required Uint8List bytes,
    required String originalFilename,
    required String mimeType,
    String? derivedFromEvidenceId,
  });

  /// Retrieves the preserved original bytes from managed storage.
  Future<Uint8List> openOriginalBytes(String storageIdentifier);

  /// Reads the preserved bytes, checks byte size, and recalculates the SHA-256 digest
  /// to verify they match the expectations.
  Future<EvidenceVerificationState> verify({
    required String storageIdentifier,
    required String expectedSha256,
    required int expectedByteSize,
  });

  /// Checks whether a managed asset exists in storage.
  Future<bool> exists(String storageIdentifier);

  /// Resolves the local absolute path of the managed file for native SDK consumption (e.g. PDF viewers).
  /// This should only be used after `verify()` returns a successful state.
  Future<String> getLocalFilePath(String storageIdentifier);

  /// Deletes a draft asset. Only permitted if the asset has not been linked to a finalized record.
  Future<void> deleteDraftAsset(String storageIdentifier);
}
