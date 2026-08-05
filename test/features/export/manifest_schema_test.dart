import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;
import 'package:tekmerion/src/features/agreement/domain/agreement.dart';
import 'package:tekmerion/src/features/agreement/domain/agreement_version.dart';
import 'package:tekmerion/src/features/export/application/export_state.dart';
import 'package:tekmerion/src/features/export/application/record_package_export_service.dart';
import 'package:tekmerion/src/features/export/domain/export_manifest.dart';
import 'package:tekmerion/src/features/export/domain/export_manifest_validator.dart';
import 'package:tekmerion/src/features/record/domain/evidence_envelope.dart';
import 'package:tekmerion/src/features/record/domain/evidence_reference.dart';

import 'record_package_export_service_test.dart' as fakes;

void main() {
  group('ExportManifest Schema Validation', () {
    late JsonSchema schema;
    late ExportManifestValidator validator;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final schemaFile = File(
        p.join(
          Directory.current.path,
          'schemas',
          'export-manifest.schema.json',
        ),
      );
      final schemaString = await schemaFile.readAsString();
      schema = JsonSchema.create(jsonDecode(schemaString) as Object);
      validator = ExportManifestValidator(schema);
    });

    ExportManifest createValidManifest() {
      return ExportManifest(
        packageId: '123e4567-e89b-12d3-a456-426614174000',
        generatedAt: DateTime.utc(2026, 8, 4, 12, 0, 0),
        generatedTimezone: 'UTC',
        generator: const GeneratorInfo(
          applicationVersion: '1.0.0',
          buildNumber: '42',
          platform: 'android',
        ),
        scope: const ScopeInfo(
          scopeType: 'full_agreement',
          completeAgreementChain: true,
          filters: {},
          completenessState: 'complete',
          completenessWarnings: null,
        ),
        agreement: const AgreementInfo(
          agreementId: 'a1b2c3d4-e89b-12d3-a456-426614174000',
          title: 'Test Agreement',
          agreementType: 'lease',
          versions: [],
          parties: [],
          clauses: [],
          obligations: [],
        ),
        records: [],
        evidence: [],
        files: [],
        integrity: const IntegrityInfo(
          manifestSha256:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          verificationStatus: 'verified',
          chainScope: 'complete_agreement_chain',
        ),
        disclaimers: ['Disclaimer 1'],
      );
    }

    test('valid manifest passes schema validation', () {
      final manifest = createValidManifest();
      final json =
          jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>;

      final errors = validator.validate(json);
      expect(errors, isEmpty);
    });

    test('fails when a required field is removed', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json.remove('generated_at');

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('fails when an invalid enum is introduced', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      (json['generator'] as Map<String, dynamic>)['platform'] = 'windows';

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('fails when a malformed SHA-256 is introduced', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      (json['integrity'] as Map<String, dynamic>)['manifest_sha256'] =
          'invalid-hash-too-short';

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('rejects unexpected properties when schema forbids them', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json['unexpected_property'] = 'should fail';

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('fails when invalid UUID is introduced', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json['package_id'] = 'not-a-uuid';

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('fails when invalid timestamp is introduced', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json['generated_at'] = '2026-08-04'; // Not RFC 3339

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('fails on duplicate paths', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json['files'] = [
        {
          'path': 'data/test.json',
          'sha256':
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'byte_size': 1,
        },
        {
          'path': 'data/test.json',
          'sha256':
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'byte_size': 1,
        },
      ];

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('fails on unsafe paths', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json['files'] = [
        {
          'path': '../data/test.json',
          'sha256':
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'byte_size': 1,
        },
      ];

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('fails on absolute paths', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json['files'] = [
        {
          'path': '/data/test.json',
          'sha256':
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'byte_size': 1,
        },
      ];

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('fails on backslash paths', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json['files'] = [
        {
          'path': 'data\\test.json',
          'sha256':
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'byte_size': 1,
        },
      ];

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('fails on empty paths', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json['files'] = [
        {
          'path': '',
          'sha256':
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'byte_size': 1,
        },
      ];

      final errors = validator
          .validate(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(errors, isNotEmpty);
    });

    test('real manifest validation using RecordPackageExportService', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('export_schema_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getTemporaryDirectory') {
            return tempDir.path;
          }
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          return null;
        },
      );

      final agreementBytes = Uint8List.fromList([10, 20, 30, 40]);
      final originalHash = sha256.convert(agreementBytes).toString();

      final agreement = Agreement(
        id: '11111111-1111-1111-1111-111111111111',
        title: 'Lease',
        agreementType: 'lease',
        status: AgreementStatus.active,
        createdAt: DateTime.now(),
      );

      final version = AgreementVersion(
        id: '22222222-2222-2222-2222-222222222222',
        agreementId: '11111111-1111-1111-1111-111111111111',
        sourceEvidenceAssetId: '66666666-6666-6666-6666-666666666661',
        versionLabel: 'Original',
        status: AgreementVersionStatus.active,
        importedAt: DateTime.now(),
      );

      final evidenceEnvelope = EvidenceEnvelope(
        evidenceId: '66666666-6666-6666-6666-666666666661',
        originalFilename: 'lease.pdf',
        mimeType: 'application/pdf',
        byteSize: agreementBytes.length,
        sha256: originalHash,
        captureMethod: EvidenceCaptureMethod.externalImport,
        ingestedAt: DateTime.now(),
        storageIdentifier: '66666666-6666-6666-6666-666666666661',
        assetRole: EvidenceAssetRole.original,
      );

      final service = RecordPackageExportService(
        agreementRepo: fakes.FakeAgreementRepository(
          [agreement],
          [version],
          {'66666666-6666-6666-6666-666666666661': evidenceEnvelope},
        ),
        clauseRepo: fakes.FakeClauseRepository(),
        obligationRepo: fakes.FakeObligationRepository(),
        recordRepo: fakes.FakeRecordRepository(),
        timelineRepo: fakes.FakeTimelineRepository(),
        evidenceStorage: fakes.FakeEvidenceStorage(
            {'66666666-6666-6666-6666-666666666661': agreementBytes}),
        exportRepo: fakes.FakeExportPackageRepository(),
        pdfGenerator: fakes.FakeRecordPdfGenerator(),
      );

      final statuses = await service
          .generateCompleteExport('11111111-1111-1111-1111-111111111111')
          .toList();
      final finalStatus = statuses.last;

      expect(finalStatus.state, ExportState.completed);
      expect(finalStatus.packageFilePath, isNotNull);

      final zipFile = File(finalStatus.packageFilePath!);
      final zipBytes = await zipFile.readAsBytes();

      final archive = ZipDecoder().decodeBytes(zipBytes);
      final manifestArchiveFile = archive.findFile('manifest.json');
      expect(manifestArchiveFile, isNotNull);

      final manifestContent =
          utf8.decode(manifestArchiveFile!.content as List<int>);
      final manifestJson = jsonDecode(manifestContent) as Map<String, dynamic>;

      // Validate the emitted JSON against schema and supplementary rules
      final validationResult = schema.validate(manifestJson);
      expect(
        validationResult.isValid,
        isTrue,
        reason: validationResult.errors.map((e) => e.toString()).join(', '),
      );

      final customErrors = validator.validate(manifestJson);
      expect(customErrors, isEmpty, reason: customErrors.join(', '));
    });
  });
}
