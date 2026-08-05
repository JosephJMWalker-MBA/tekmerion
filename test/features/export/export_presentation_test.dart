import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/export/application/record_pdf_generator.dart';
import 'package:tekmerion/src/features/export/domain/export_manifest.dart';

void main() {
  group('RecordPdfGenerator Presentation Parity', () {
    test('Generated PDF contains required sections and distinguishes content',
        () async {
      final manifest = ExportManifest(
        packageId: 'test-pkg',
        generatedAt: DateTime.now().toUtc(),
        generatedTimezone: 'UTC',
        generator: const GeneratorInfo(
          applicationVersion: '1.0.0',
          buildNumber: '1',
          platform: 'test',
        ),
        scope: const ScopeInfo(
          scopeType: 'full_agreement',
          completeAgreementChain: true,
          filters: {},
          completenessState: 'complete',
          completenessWarnings: null,
        ),
        files: [],
        integrity: const IntegrityInfo(
          manifestSha256: 'hash',
          verificationStatus: 'verified',
          chainScope: 'complete_agreement_chain',
        ),
        disclaimers: [],
        agreement: AgreementInfo(
          agreementId: '123e4567-e89b-12d3-a456-426614174000',
          title: 'Master Lease',
          agreementType: 'lease',
          versions: [
            AgreementVersionInfo(
              agreementVersionId: '123e4567-e89b-12d3-a456-426614174001',
              versionLabel: 'Original',
              status: 'active',
              sourceFilePath: 'agreement/orig.pdf',
              sourceFileSha256: 'hash1',
            ),
          ],
          parties: [],
          clauses: [],
          obligations: [
            ObligationInfo(
                obligationId: '123e4567-e89b-12d3-a456-426614174002',
                agreementId: "a1",
                sourceType: 'contractual',
                title: 'Pay Rent',
                description: 'Rent is due',
                obligationCategory: "standard",
                status: 'confirmed',
                confirmedAt: DateTime.now().toUtc(),
                createdAt: DateTime.parse("2024-01-01T00:00:00Z")),
          ],
        ),
        records: [
          RecordInfo(
            recordId: '123e4567-e89b-12d3-a456-426614174003',
            recordType: 'performance',
            title: 'Paid Rent',
            factualDescription: 'Wire transfer',
            occurredAt: DateTime.now().toUtc(),
            recordedAt: DateTime.now().toUtc(),
            finalizedAt: DateTime.now().toUtc(),
            timezone: 'UTC',
            recordHash: 'hash',
            chainHash: 'chain',
            evidenceIds: [],
          ),
          RecordInfo(
            recordId: '123e4567-e89b-12d3-a456-426614174004',
            recordType: 'correction',
            title: 'Fixed Rent Amount',
            factualDescription: 'Was off by 1 cent',
            occurredAt: DateTime.now().toUtc(),
            recordedAt: DateTime.now().toUtc(),
            finalizedAt: DateTime.now().toUtc(),
            timezone: 'UTC',
            correctsRecordId: '123e4567-e89b-12d3-a456-426614174003',
            recordHash: 'hash2',
            chainHash: 'chain2',
            evidenceIds: [],
          ),
        ],
        evidence: [
          EvidenceInfo(
            evidenceId: '123e4567-e89b-12d3-a456-426614174005',
            packagePath: 'evidence/e1.bin',
            mimeType: 'application/pdf',
            byteSize: 123,
            sha256: 'hash1',
            captureMethod: 'externalImport',
            importedAt: DateTime.now().toUtc(),
            assetRole: 'original',
            verificationState: 'verified',
            provenanceStatus: 'captured_in_app',
          ),
        ],
      );

      final generator = RecordPdfGenerator();
      final bytes = await generator.generatePdf(manifest);

      final tempDir = Directory.systemTemp.createTempSync('pdf_test');
      final pdfFile = File('${tempDir.path}/record.pdf');
      pdfFile.writeAsBytesSync(bytes);

      try {
        Process.runSync('pdftotext', ['-v']);
      } catch (e) {
        fail(
          'pdftotext executable is not available in PATH. It is required for PDF content coverage test. Error: $e',
        );
      }

      final result = Process.runSync('pdftotext', [pdfFile.path, '-']);
      final text = result.stdout as String;
      final textLower = text.toLowerCase();

      expect(textLower, contains('master lease'));
      expect(textLower, contains('export scope and completeness statement'));
      expect(textLower, contains('disclaimers'));
      expect(textLower, contains('confirmed obligation register'));
      expect(textLower, contains('chronological timeline'));
      expect(textLower, contains('occurred at:'));
      expect(textLower, contains('recorded at:'));
      expect(textLower, contains('evidence index'));
      expect(textLower, contains('correction history'));
      expect(textLower, contains('integrity verification summary'));
      expect(textLower, contains('file-hash appendix'));
      expect(textLower.contains('draft'), isFalse);

      tempDir.deleteSync(recursive: true);
    });
  });
}
