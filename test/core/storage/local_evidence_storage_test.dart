import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/core/storage/evidence_storage.dart';
import 'package:tekmerion/src/core/storage/local_evidence_storage.dart';
import 'package:tekmerion/src/features/record/domain/evidence_reference.dart';

void main() {
  group('LocalEvidenceStorage', () {
    late Directory tempRoot;
    late LocalEvidenceStorage storage;

    setUp(() async {
      tempRoot =
          await Directory.systemTemp.createTemp('tekmerion_storage_test_');
      storage = LocalEvidenceStorage(getRootDirectory: () async => tempRoot);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('ingestExternalFile preserves byte-identical content', () async {
      // Create a dummy source file
      final sourceFile = File('${tempRoot.path}/source.jpg');
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      await sourceFile.writeAsBytes(bytes);

      final envelope = await storage.ingestExternalFile(
        sourceFilePath: sourceFile.path,
        originalFilename: 'source.jpg',
        mimeType: 'image/jpeg',
      );

      final storedFile = File('${tempRoot.path}/${envelope.storageIdentifier}');
      expect(await storedFile.exists(), isTrue);

      final storedBytes = await storedFile.readAsBytes();
      expect(storedBytes, equals(bytes));
    });

    test('recorded byte size matches stored bytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final envelope = await storage.ingestCapturedBytes(
        bytes: bytes,
        originalFilename: 'capture.png',
        mimeType: 'image/png',
      );

      expect(envelope.byteSize, equals(5));
      final storedFile = File('${tempRoot.path}/${envelope.storageIdentifier}');
      expect(await storedFile.length(), equals(5));
    });

    test('recorded SHA-256 matches a known recalculation', () async {
      final bytes = Uint8List.fromList([0x00, 0xFF, 0x5A, 0xA5]);
      final envelope = await storage.ingestCapturedBytes(
        bytes: bytes,
        originalFilename: 'test.bin',
        mimeType: 'application/octet-stream',
      );

      final expectedHash =
          '7ab1f643e89d80aeaff9f5a1dd6f38b43634f63b3958ce94283ed400fcc821a0';
      expect(envelope.sha256, equals(expectedHash));
    });

    test('read-back returns exact original bytes', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final envelope = await storage.ingestCapturedBytes(
        bytes: bytes,
        originalFilename: 'test.bin',
        mimeType: 'application/octet-stream',
      );

      final readBack =
          await storage.openOriginalBytes(envelope.storageIdentifier);
      expect(readBack, equals(bytes));
    });

    test('verification succeeds immediately after ingestion', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final envelope = await storage.ingestCapturedBytes(
        bytes: bytes,
        originalFilename: 'test.bin',
        mimeType: 'application/octet-stream',
      );

      final state = await storage.verify(
        storageIdentifier: envelope.storageIdentifier,
        expectedSha256: envelope.sha256,
        expectedByteSize: envelope.byteSize,
      );

      expect(
        state,
        equals(EvidenceVerificationState.verifiedUnchangedSinceIngestion),
      );
    });

    test('changing one stored byte causes verification failure', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final envelope = await storage.ingestCapturedBytes(
        bytes: bytes,
        originalFilename: 'test.bin',
        mimeType: 'application/octet-stream',
      );

      // Mutate the stored file
      final storedFile = File('${tempRoot.path}/${envelope.storageIdentifier}');
      final mutatedBytes = Uint8List.fromList([10, 21, 30]);
      await storedFile.writeAsBytes(mutatedBytes);

      final state = await storage.verify(
        storageIdentifier: envelope.storageIdentifier,
        expectedSha256: envelope.sha256,
        expectedByteSize: envelope.byteSize,
      );

      expect(state, equals(EvidenceVerificationState.hashMismatch));
    });

    test('deleting the managed file produces missing status', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final envelope = await storage.ingestCapturedBytes(
        bytes: bytes,
        originalFilename: 'test.bin',
        mimeType: 'application/octet-stream',
      );

      await storage.deleteDraftAsset(envelope.storageIdentifier);

      final state = await storage.verify(
        storageIdentifier: envelope.storageIdentifier,
        expectedSha256: envelope.sha256,
        expectedByteSize: envelope.byteSize,
      );

      expect(state, equals(EvidenceVerificationState.missing));
    });

    test('unsafe filenames cannot escape managed storage', () async {
      final bytes = Uint8List.fromList([1]);
      final envelope = await storage.ingestCapturedBytes(
        bytes: bytes,
        originalFilename: '../../../etc/passwd',
        mimeType: 'text/plain',
      );

      // The sanitizer should extract the basename and replace dangerous chars
      expect(envelope.storageIdentifier.contains('..'), isFalse);
      expect(
        envelope.storageIdentifier.contains('etc'),
        isFalse,
      );
      expect(
        envelope.storageIdentifier.contains('passwd'),
        isTrue,
      );

      // Manually passing bad paths to verify/open should throw
      expect(
        () => storage.openOriginalBytes('../../../escaped'),
        throwsArgumentError,
      );
    });

    test('a derivative receives a separate ID, hash, and storage location',
        () async {
      final originalBytes = Uint8List.fromList([1, 2, 3]);
      final originalEnvelope = await storage.ingestCapturedBytes(
        bytes: originalBytes,
        originalFilename: 'orig.png',
        mimeType: 'image/png',
      );

      final derivativeBytes = Uint8List.fromList([9, 9]);
      final derivativeEnvelope = await storage.ingestCapturedBytes(
        bytes: derivativeBytes,
        originalFilename: 'thumb.png',
        mimeType: 'image/png',
        derivedFromEvidenceId: originalEnvelope.evidenceId,
      );

      expect(
        derivativeEnvelope.evidenceId,
        isNot(equals(originalEnvelope.evidenceId)),
      );
      expect(derivativeEnvelope.sha256, isNot(equals(originalEnvelope.sha256)));
      expect(
        derivativeEnvelope.storageIdentifier,
        isNot(equals(originalEnvelope.storageIdentifier)),
      );
      expect(
        derivativeEnvelope.derivedFromEvidenceId,
        equals(originalEnvelope.evidenceId),
      );
      expect(derivativeEnvelope.assetRole, equals(EvidenceAssetRole.preview));
    });

    test('original bytes remain unchanged after derivative ingestion',
        () async {
      final originalBytes = Uint8List.fromList([1, 2, 3]);
      final originalEnvelope = await storage.ingestCapturedBytes(
        bytes: originalBytes,
        originalFilename: 'orig.png',
        mimeType: 'image/png',
      );

      final derivativeBytes = Uint8List.fromList([9, 9]);
      await storage.ingestCapturedBytes(
        bytes: derivativeBytes,
        originalFilename: 'thumb.png',
        mimeType: 'image/png',
        derivedFromEvidenceId: originalEnvelope.evidenceId,
      );

      final readBack =
          await storage.openOriginalBytes(originalEnvelope.storageIdentifier);
      expect(readBack, equals(originalBytes));
    });

    test(
        'imported evidence remains labeled with unknown pre-ingestion provenance',
        () async {
      final sourceFile = File('${tempRoot.path}/source.jpg');
      await sourceFile.writeAsBytes([1]);

      final envelope = await storage.ingestExternalFile(
        sourceFilePath: sourceFile.path,
        originalFilename: 'source.jpg',
        mimeType: 'image/jpeg',
      );

      expect(
        envelope.captureMethod,
        equals(EvidenceCaptureMethod.externalImport),
      );
    });
  });
}
