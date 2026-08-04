import 'dart:convert';

import 'record_entry.dart';

class RecordCanonicalizer {
  const RecordCanonicalizer();

  static const String schemaVersion = '1.0.0';

  List<int> canonicalBytes(RecordEntry record, DateTime finalizedAt) {
    final List<Map<String, Object?>> evidence = record.evidence
        .map(
          (item) => <String, Object?>{
            'asset_role': item.assetRole.name,
            'capture_method': item.captureMethod.name,
            'evidence_id': item.evidenceId,
            'sha256': item.sha256,
          },
        )
        .toList()
      ..sort(
        (Map<String, Object?> left, Map<String, Object?> right) =>
            (left['evidence_id']! as String).compareTo(
          right['evidence_id']! as String,
        ),
      );

    final Map<String, Object?> payload = <String, Object?>{
      'agreement_id': record.agreementId,
      'agreement_version_id': record.agreementVersionId,
      'corrects_record_entry_id': record.correctsRecordEntryId,
      'created_by_party_id': record.createdByPartyId,
      'evidence': evidence,
      'factual_description': record.factualDescription,
      'finalized_at': finalizedAt.toUtc().toIso8601String(),
      'interpretation_text': record.interpretationText,
      'obligation_id': record.obligationId,
      'occurred_at': record.occurredAt.toUtc().toIso8601String(),
      'record_id': record.id,
      'record_type': record.recordType.name,
      'recorded_at': record.recordedAt.toUtc().toIso8601String(),
      'schema_version': schemaVersion,
      'source_clause_id': record.sourceClauseId,
      'timezone': record.timezone,
      'title': record.title,
      'workspace_id': record.workspaceId,
    };

    return utf8.encode(jsonEncode(payload));
  }
}
