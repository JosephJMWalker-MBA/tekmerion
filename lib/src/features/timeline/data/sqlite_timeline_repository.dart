import 'package:sqflite/sqflite.dart';
import '../domain/timeline_event.dart';
import '../domain/timeline_repository.dart';

class SqliteTimelineRepository implements TimelineRepository {
  SqliteTimelineRepository(this._db);

  final Database _db;

  @override
  Future<List<TimelineEvent>> getTimelineForAgreement(
    String agreementId,
  ) async {
    const query = '''
SELECT 
  id, agreementId, eventType, occurredAt, recordedAt, title, summary, 
  provenanceType, sourceObjectType, sourceObjectId, integrityState, displayPriority 
FROM (
  -- 1. AgreementImported
  SELECT 
    id as id,
    id as agreementId,
    'agreementImported' as eventType,
    created_at as occurredAt,
    created_at as recordedAt,
    'Lease imported' as title,
    title as summary,
    'user' as provenanceType,
    'Agreement' as sourceObjectType,
    id as sourceObjectId,
    'verified' as integrityState,
    1 as displayPriority
  FROM agreements
  WHERE id = ?

  UNION ALL

  -- 2. AgreementVersionCreated
  SELECT 
    v.id as id,
    v.agreement_id as agreementId,
    'agreementVersionCreated' as eventType,
    v.imported_at as occurredAt,
    v.imported_at as recordedAt,
    'Agreement version created' as title,
    v.version_label as summary,
    'system' as provenanceType,
    'AgreementVersion' as sourceObjectType,
    v.id as sourceObjectId,
    'verified' as integrityState,
    1 as displayPriority
  FROM agreement_versions v
  WHERE v.agreement_id = ?

  UNION ALL

  -- 3. ClauseConfirmed
  SELECT 
    c.id as id,
    v.agreement_id as agreementId,
    'clauseConfirmed' as eventType,
    c.confirmed_at as occurredAt,
    c.confirmed_at as recordedAt,
    'Clause confirmed' as title,
    CASE WHEN c.clause_number IS NOT NULL THEN 'Clause ' || c.clause_number ELSE 'Clause confirmed' END as summary,
    'user' as provenanceType,
    'Clause' as sourceObjectType,
    c.id as sourceObjectId,
    'verified' as integrityState,
    1 as displayPriority
  FROM clauses c
  JOIN agreement_versions v ON c.agreement_version_id = v.id
  WHERE v.agreement_id = ? AND c.confirmed_at IS NOT NULL

  UNION ALL

  -- 4. ObligationConfirmed
  SELECT 
    o.id as id,
    o.agreement_id as agreementId,
    'obligationConfirmed' as eventType,
    o.confirmed_at as occurredAt,
    o.confirmed_at as recordedAt,
    'Obligation created' as title,
    o.title as summary,
    'user' as provenanceType,
    'Obligation' as sourceObjectType,
    o.id as sourceObjectId,
    'verified' as integrityState,
    1 as displayPriority
  FROM obligations o
  WHERE o.agreement_id = ? AND o.confirmed_at IS NOT NULL

  UNION ALL

  -- 5. ObligationCompleted (Derived from finalized performance record entry)
  SELECT 
    r.id || '_completed' as id,
    r.agreement_id as agreementId,
    'obligationCompleted' as eventType,
    r.occurred_at as occurredAt,
    r.recorded_at as recordedAt,
    'Obligation completed' as title,
    r.title as summary,
    'user' as provenanceType,
    'RecordEntry' as sourceObjectType,
    r.id as sourceObjectId,
    'verified' as integrityState,
    1 as displayPriority
  FROM record_entries r
  WHERE r.agreement_id = ? AND r.state = 'finalized' AND r.record_type = 'performance' AND r.obligation_id IS NOT NULL

  UNION ALL

  -- 6. RecordFinalized
  SELECT 
    r.id || '_finalized' as id,
    r.agreement_id as agreementId,
    'recordFinalized' as eventType,
    r.finalized_at as occurredAt,
    r.finalized_at as recordedAt,
    'Record finalized' as title,
    r.title as summary,
    'system' as provenanceType,
    'RecordEntry' as sourceObjectType,
    r.id as sourceObjectId,
    'verified' as integrityState,
    0 as displayPriority
  FROM record_entries r
  WHERE r.agreement_id = ? AND r.state = 'finalized'

  UNION ALL

  -- 7. EvidenceAttached
  SELECT 
    e.id || '_' || rel.id as id,
    r.agreement_id as agreementId,
    'evidenceAttached' as eventType,
    r.recorded_at as occurredAt, 
    r.recorded_at as recordedAt,
    'Receipt attached' as title,
    e.original_filename as summary,
    'user' as provenanceType,
    'EvidenceAsset' as sourceObjectType,
    e.id as sourceObjectId,
    'verified' as integrityState,
    0 as displayPriority
  FROM record_evidence_links rel
  JOIN evidence_assets e ON rel.evidence_asset_id = e.id
  JOIN record_entries r ON rel.record_entry_id = r.id
  WHERE r.agreement_id = ? AND r.state = 'finalized'

  UNION ALL

  -- 8. ExportGenerated
  SELECT 
    xp.id as id,
    xp.agreement_id as agreementId,
    'exportGenerated' as eventType,
    xp.generated_at as occurredAt,
    xp.generated_at as recordedAt,
    'Export generated' as title,
    xp.format as summary,
    'system' as provenanceType,
    'ExportPackage' as sourceObjectType,
    xp.id as sourceObjectId,
    'verified' as integrityState,
    0 as displayPriority
  FROM export_packages xp
  WHERE xp.agreement_id = ?
)
ORDER BY recordedAt DESC, displayPriority DESC, id DESC
    ''';

    final result = await _db.rawQuery(
      query,
      List.filled(8, agreementId),
    );

    return result.map((row) {
      return TimelineEvent(
        id: row['id'] as String,
        agreementId: row['agreementId'] as String,
        eventType: TimelineEventType.values
            .firstWhere((e) => e.name == row['eventType']),
        occurredAt: DateTime.parse(row['occurredAt'] as String),
        recordedAt: DateTime.parse(row['recordedAt'] as String),
        title: row['title'] as String,
        summary: row['summary'] as String,
        provenanceType: TimelineEventProvenance.values
            .firstWhere((e) => e.name == row['provenanceType']),
        sourceObjectType: row['sourceObjectType'] as String,
        sourceObjectId: row['sourceObjectId'] as String,
        integrityState: TimelineIntegrityState.values
            .firstWhere((e) => e.name == row['integrityState']),
        displayPriority: (row['displayPriority'] as num).toInt(),
      );
    }).toList();
  }
}
