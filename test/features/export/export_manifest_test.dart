import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/export/domain/export_manifest.dart';

void main() {
  group('ExportManifest', () {
    test('serializes exactly according to schema', () {
      final manifest = ExportManifest(
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
          agreementId: 'a1',
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

      final json = manifest.toJson();

      expect(json['schema_version'], '1.0.0');
      expect(json['package_id'], '123e4567-e89b-12d3-a456-426614174000');
      expect(json['generated_at'], '2026-08-04T12:00:00.000Z');
      expect((json['generator'] as Map<String, dynamic>)['application'],
          'Tekmerion',);
      expect(json['disclaimers'], ['Disclaimer 1']);
    });
  });
}
