import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/export_manifest.dart';

class RecordPdfGenerator {
  Future<Uint8List> generatePdf(ExportManifest manifest) async {
    final pdf = pw.Document();

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
    );

    // 1. Cover page
    pdf.addPage(
      pw.Page(
        theme: theme,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Record Export Package',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Text(
                  'Agreement: ${manifest.agreement.title}',
                  style: pw.TextStyle(fontSize: 20),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Package ID: ${manifest.packageId}',
                  style: const pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated At: ${manifest.generatedAt.toUtc().toIso8601String()} (${manifest.generatedTimezone})',
                  style: const pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // 2-6. Scope, Disclaimers, Agreement Summary, Versions, Parties
    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        build: (pw.Context context) {
          return [
            _buildHeader('2. Export Scope and Completeness Statement'),
            pw.Text('Scope Type: ${manifest.scope.scopeType}'),
            pw.Text(
              'Complete Agreement Chain: ${manifest.scope.completeAgreementChain ? "Yes" : "No"}',
            ),
            if (manifest.scope.completenessWarnings.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                'Completeness Warnings:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red,
                ),
              ),
              ...manifest.scope.completenessWarnings
                  .map((w) => pw.Bullet(text: w)),
            ],
            pw.SizedBox(height: 24),
            _buildHeader('3. Disclaimers'),
            if (manifest.disclaimers.isEmpty)
              pw.Text('No disclaimers provided.')
            else
              ...manifest.disclaimers.map((d) => pw.Paragraph(text: d)),
            pw.SizedBox(height: 24),
            _buildHeader('4. Agreement Summary'),
            pw.Text('Agreement ID: ${manifest.agreement.agreementId}'),
            pw.Text('Title: ${manifest.agreement.title}'),
            pw.Text('Type: ${manifest.agreement.agreementType}'),
            if (manifest.agreement.subjectId != null)
              pw.Text('Subject ID: ${manifest.agreement.subjectId}'),
            if (manifest.agreement.lifecycleStage != null)
              pw.Text('Lifecycle Stage: ${manifest.agreement.lifecycleStage}'),
            pw.SizedBox(height: 24),
            _buildHeader('5. Agreement Versions and Source Documents'),
            ...manifest.agreement.versions.map(
              (v) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Version: ${v.versionLabel} (${v.agreementVersionId})',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('Status: ${v.status}'),
                    pw.Text('Source Path: ${v.sourceFilePath}'),
                    pw.Text('Source SHA-256: ${v.sourceFileSha256}'),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 24),
            _buildHeader('6. Parties and Subject Information'),
            ...manifest.agreement.parties.map(
              (p) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Party: ${p.displayName} (${p.partyId})',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (p.partyType != null) pw.Text('Type: ${p.partyType}'),
                    pw.Text('Roles: ${p.roles.join(", ")}'),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    // 7. Confirmed Obligation Register
    if (manifest.agreement.obligations.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          build: (pw.Context context) {
            return [
              _buildHeader('7. Confirmed Obligation Register'),
              ...manifest.agreement.obligations.map(
                (o) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        o.title,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'ID: ${o.obligationId}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(o.description),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Status: ${o.status} | Source: ${o.sourceType}',
                        style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
        ),
      );
    }

    // 8. Chronological Timeline & 9. Record Details
    final sortedRecords = List<RecordInfo>.from(manifest.records)
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    if (sortedRecords.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          build: (pw.Context context) {
            return [
              _buildHeader('8. Chronological Timeline & 9. Record Details'),
              ...sortedRecords.map((r) {
                final color = _getColorForRecordType(r.recordType);
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 16),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border:
                        pw.Border(left: pw.BorderSide(color: color, width: 4)),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            r.title,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: color,
                              fontSize: 14,
                            ),
                          ),
                          pw.Text(
                            r.occurredAt.toUtc().toIso8601String(),
                            style: const pw.TextStyle(
                              color: PdfColors.grey600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '[${_getLabelForRecordType(r.recordType)}] Type: ${r.recordType}',
                        style: pw.TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(r.factualDescription),
                      if (r.interpretationText != null) ...[
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Interpretation:',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          r.interpretationText!,
                          style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                        ),
                      ],
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Record Hash: ${r.recordHash}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey500,
                        ),
                      ),
                      if (r.evidenceIds.isNotEmpty)
                        pw.Text(
                          'Evidence IDs: ${r.evidenceIds.join(", ")}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey500,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      );
    }

    // 10. Evidence Index
    if (manifest.evidence.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          build: (pw.Context context) {
            return [
              _buildHeader('10. Evidence Index'),
              pw.TableHelper.fromTextArray(
                context: context,
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                headers: [
                  'ID',
                  'Role',
                  'File/Path',
                  'MIME',
                  'SHA-256 (prefix)',
                ],
                data: manifest.evidence
                    .map(
                      (e) => [
                        e.evidenceId,
                        e.assetRole,
                        e.originalFilename ?? e.packagePath,
                        e.mimeType,
                        e.sha256.length > 16
                            ? '${e.sha256.substring(0, 16)}...'
                            : e.sha256,
                      ],
                    )
                    .toList(),
              ),
            ];
          },
        ),
      );
    }

    // 11. Correction History
    final corrections =
        manifest.records.where((r) => r.correctsRecordId != null).toList();
    if (corrections.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          build: (pw.Context context) {
            return [
              _buildHeader('11. Correction History'),
              ...corrections.map(
                (r) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Record [${r.recordId}] corrects [${r.correctsRecordId}]',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Details: ${r.factualDescription}'),
                    ],
                  ),
                ),
              ),
            ];
          },
        ),
      );
    }

    // 12. Integrity Verification & 13. File-Hash Appendix
    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        build: (pw.Context context) {
          return [
            _buildHeader('12. Integrity Verification Summary'),
            pw.Text('Status: ${manifest.integrity.verificationStatus}'),
            pw.Text('Chain Scope: ${manifest.integrity.chainScope}'),
            pw.Text('Manifest SHA-256: ${manifest.integrity.manifestSha256}'),
            if (manifest.integrity.manifestSignaturePath != null)
              pw.Text(
                'Signature Path: ${manifest.integrity.manifestSignaturePath}',
              ),
            if (manifest.integrity.verificationReportPath != null)
              pw.Text(
                'Report Path: ${manifest.integrity.verificationReportPath}',
              ),
            pw.SizedBox(height: 24),
            _buildHeader('13. File-Hash Appendix'),
            pw.TableHelper.fromTextArray(
              context: context,
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              headers: [
                'Path',
                'Media Type',
                'Size (Bytes)',
                'SHA-256 (prefix)',
              ],
              data: manifest.files
                  .map(
                    (f) => [
                      f.path,
                      f.mediaType,
                      f.byteSize.toString(),
                      f.sha256.length > 16
                          ? '${f.sha256.substring(0, 16)}...'
                          : f.sha256,
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildHeader(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12, top: 16),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
        ),
      ),
    );
  }

  PdfColor _getColorForRecordType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('observation')) {
      return PdfColors.blue;
    } else if (lower.contains('performance') || lower.contains('completion')) {
      return PdfColors.green;
    } else if (lower.contains('import') || lower.contains('source')) {
      return PdfColors.orange;
    } else if (lower.contains('correction')) {
      return PdfColors.red;
    }
    return PdfColors.grey800; // default
  }

  String _getLabelForRecordType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('observation')) {
      return 'OBSERVATION';
    } else if (lower.contains('performance') || lower.contains('completion')) {
      return 'COMPLETION';
    } else if (lower.contains('import') || lower.contains('source')) {
      return 'SOURCE IMPORT';
    } else if (lower.contains('correction')) {
      return 'CORRECTION';
    }
    return 'EVENT';
  }
}
