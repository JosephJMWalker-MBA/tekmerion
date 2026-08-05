import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;
import 'package:tekmerion/src/features/export/domain/export_manifest.dart';

void main() {
  group('ExportManifest Schema Validation', () {
    late JsonSchema schema;

    setUpAll(() async {
      final schemaFile = File(
        p.join(
          Directory.current.path,
          'schemas',
          'export-manifest.schema.json',
        ),
      );
      final schemaString = await schemaFile.readAsString();
      schema = JsonSchema.create(jsonDecode(schemaString) as Object);
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
        ),
        agreement: const AgreementInfo(
          agreementId: 'a1b2c3d4-e89b-12d3-a456-426614174000',
          title: 'Test Agreement',
          agreementType: 'lease',
          versions: [],
          parties: [],
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
          jsonDecode(jsonEncode(manifest.toJson())); // ensure clean json

      final validationResult = schema.validate(json);
      expect(
        validationResult.isValid,
        isTrue,
        reason: validationResult.errors.map((e) => e.toString()).join(', '),
      );
    });

    test('fails when a required field is removed', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json.remove('generated_at'); // Remove required field

      final validationResult = schema.validate(jsonDecode(jsonEncode(json)));
      expect(validationResult.isValid, isFalse);
    });

    test('fails when an invalid enum is introduced', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      (json['generator'] as Map<String, dynamic>)['platform'] =
          'windows'; // Invalid enum, expected android, ios, other

      final validationResult = schema.validate(jsonDecode(jsonEncode(json)));
      expect(validationResult.isValid, isFalse);
    });

    test('fails when a malformed SHA-256 is introduced', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      (json['integrity'] as Map<String, dynamic>)['manifest_sha256'] =
          'invalid-hash-too-short';

      final validationResult = schema.validate(jsonDecode(jsonEncode(json)));
      expect(validationResult.isValid, isFalse);
    });

    test('rejects unexpected properties when schema forbids them', () {
      final manifest = createValidManifest();
      final json = manifest.toJson();
      json['unexpected_property'] =
          'should fail'; // additionalProperties: false

      final validationResult = schema.validate(jsonDecode(jsonEncode(json)));
      expect(validationResult.isValid, isFalse);
    });
  });
}
