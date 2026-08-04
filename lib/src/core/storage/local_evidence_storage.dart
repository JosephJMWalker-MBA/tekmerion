import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';
import 'package:tekmerion/src/features/record/domain/evidence_reference.dart';
import 'package:uuid/uuid.dart';

import 'evidence_storage.dart';

class LocalEvidenceStorage implements EvidenceStorage {
  LocalEvidenceStorage({
    required Future<Directory> Function() getRootDirectory,
    Uuid? uuid,
  })  : _getRootDirectory = getRootDirectory,
        _uuid = uuid ?? const Uuid();

  final Future<Directory> Function() _getRootDirectory;
  final Uuid _uuid;

  /// Returns the sanitized filename, falling back to evidenceId if it contains invalid chars.
  String _sanitizeFilename(String originalFilename, String evidenceId) {
    // Extract basename
    var basename = originalFilename.split('/').last.split('\\').last;
    // Keep alphanumeric, period, dash, underscore
    var sanitized = basename.replaceAll(RegExp(r'[^a-zA-Z0-9.\-_]'), '_');
    sanitized = sanitized.replaceAll('..', '_');
    if (sanitized.isEmpty || sanitized == '_' || sanitized.startsWith('.')) {
      return evidenceId;
    }
    return sanitized;
  }

  Future<File> _resolveFile(String storageIdentifier) async {
    // Prevent path traversal
    if (storageIdentifier.contains('..') || storageIdentifier.startsWith('/')) {
      throw ArgumentError('Invalid storage identifier: $storageIdentifier');
    }
    final root = await _getRootDirectory();
    final path = '${root.path}/$storageIdentifier';
    return File(path);
  }

  Future<EvidenceEnvelope> _ingest({
    required Future<void> Function(File destination) writeData,
    required String originalFilename,
    required String mimeType,
    required EvidenceCaptureMethod captureMethod,
    required EvidenceAssetRole assetRole,
    String? derivedFromEvidenceId,
  }) async {
    final evidenceId = _uuid.v4();
    final sanitizedName = _sanitizeFilename(originalFilename, evidenceId);
    final storageIdentifier = 'evidence/originals/$evidenceId/$sanitizedName';

    final file = await _resolveFile(storageIdentifier);
    if (await file.exists()) {
      throw StateError('Storage collision for identifier: $storageIdentifier');
    }

    await file.parent.create(recursive: true);

    await writeData(file);

    // Read back size and hash
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw StateError('Failed to write evidence to $storageIdentifier');
    }

    final byteSize = stat.size;

    // Use stream to calculate hash (avoids reading entirely into memory for large files)
    final digest = await sha256.bind(file.openRead()).first;
    final hashString = digest.toString();

    return EvidenceEnvelope(
      evidenceId: evidenceId,
      originalFilename: originalFilename,
      mimeType: mimeType,
      byteSize: byteSize,
      sha256: hashString,
      captureMethod: captureMethod,
      ingestedAt: DateTime.now().toUtc(),
      storageIdentifier: storageIdentifier,
      assetRole: assetRole,
      derivedFromEvidenceId: derivedFromEvidenceId,
    );
  }

  @override
  Future<EvidenceEnvelope> ingestExternalFile({
    required String sourceFilePath,
    required String originalFilename,
    required String mimeType,
    String? derivedFromEvidenceId,
  }) async {
    return _ingest(
      writeData: (destination) async {
        final source = File(sourceFilePath);
        await source.copy(destination.path);
      },
      originalFilename: originalFilename,
      mimeType: mimeType,
      captureMethod: EvidenceCaptureMethod.externalImport,
      assetRole: derivedFromEvidenceId == null
          ? EvidenceAssetRole.original
          : EvidenceAssetRole
              .preview, // We will mark as preview/derivative if it's derived
      derivedFromEvidenceId: derivedFromEvidenceId,
    );
  }

  @override
  Future<EvidenceEnvelope> ingestCapturedBytes({
    required Uint8List bytes,
    required String originalFilename,
    required String mimeType,
    String? derivedFromEvidenceId,
  }) async {
    return _ingest(
      writeData: (destination) async {
        await destination.writeAsBytes(bytes, flush: true);
      },
      originalFilename: originalFilename,
      mimeType: mimeType,
      captureMethod: EvidenceCaptureMethod.inAppCapture,
      assetRole: derivedFromEvidenceId == null
          ? EvidenceAssetRole.original
          : EvidenceAssetRole.preview,
      derivedFromEvidenceId: derivedFromEvidenceId,
    );
  }

  @override
  Future<Uint8List> openOriginalBytes(String storageIdentifier) async {
    final file = await _resolveFile(storageIdentifier);
    if (!await file.exists()) {
      throw StateError('Evidence not found: $storageIdentifier');
    }
    return file.readAsBytes();
  }

  @override
  Future<EvidenceVerificationState> verify({
    required String storageIdentifier,
    required String expectedSha256,
    required int expectedByteSize,
  }) async {
    try {
      final file = await _resolveFile(storageIdentifier);
      if (!await file.exists()) {
        return EvidenceVerificationState.missing;
      }

      final stat = await file.stat();
      if (stat.size != expectedByteSize) {
        return EvidenceVerificationState.byteSizeMismatch;
      }

      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString() != expectedSha256) {
        return EvidenceVerificationState.hashMismatch;
      }

      return EvidenceVerificationState.verifiedUnchangedSinceIngestion;
    } catch (_) {
      return EvidenceVerificationState.unreadable;
    }
  }

  @override
  Future<bool> exists(String storageIdentifier) async {
    try {
      final file = await _resolveFile(storageIdentifier);
      return file.exists();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> deleteDraftAsset(String storageIdentifier) async {
    final file = await _resolveFile(storageIdentifier);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
