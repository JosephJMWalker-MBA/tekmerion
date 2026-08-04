import 'dart:typed_data';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';

abstract interface class EvidenceStorage {
  /// Ingests an external file by copying it into managed app-private storage
  /// and calculating its SHA-256 digest.
  Future<EvidenceEnvelope> ingestExternalFile({
    required String sourceFilePath,
    required String originalFilename,
    required String mimeType,
  });

  /// Ingests raw bytes captured within the application (e.g. from the camera)
  /// into managed app-private storage.
  Future<EvidenceEnvelope> ingestCapturedBytes({
    required Uint8List bytes,
    required String originalFilename,
    required String mimeType,
  });

  /// Retrieves the preserved original bytes from managed storage.
  Future<Uint8List> openPreservedBytes(String storageIdentifier);

  /// Reads the preserved bytes and recalculates the SHA-256 digest to verify
  /// they match the [expectedSha256].
  Future<bool> verifyPreservedBytes({
    required String storageIdentifier,
    required String expectedSha256,
  });

  /// Checks whether a managed asset exists in storage.
  Future<bool> exists(String storageIdentifier);
}
