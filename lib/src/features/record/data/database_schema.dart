/// Minimal SQLite schema definition for Phase 1 persistence boundary.
/// 
/// These strings define the exact schema required for the core vertical slice
/// (upload -> confirm obligation -> remind -> document -> link to clause -> export)
/// without speculatively implementing deferred features like sync or communities.
class DatabaseSchema {
  static const String createAgreementsTable = '''
    CREATE TABLE agreements (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL,
      title TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''';

  static const String createAgreementVersionsTable = '''
    CREATE TABLE agreement_versions (
      id TEXT PRIMARY KEY,
      agreement_id TEXT NOT NULL,
      source_file_id TEXT NOT NULL,
      version_number INTEGER NOT NULL,
      imported_at TEXT NOT NULL,
      FOREIGN KEY (agreement_id) REFERENCES agreements (id) ON DELETE CASCADE
    );
  ''';

  static const String createClausesTable = '''
    CREATE TABLE clauses (
      id TEXT PRIMARY KEY,
      agreement_version_id TEXT NOT NULL,
      clause_text TEXT NOT NULL,
      clause_number TEXT,
      page_index INTEGER,
      bounding_box_json TEXT,
      FOREIGN KEY (agreement_version_id) REFERENCES agreement_versions (id) ON DELETE CASCADE
    );
  ''';

  static const String createObligationsTable = '''
    CREATE TABLE obligations (
      id TEXT PRIMARY KEY,
      agreement_id TEXT NOT NULL,
      source_clause_id TEXT,
      assigned_party_id TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      status TEXT NOT NULL,
      FOREIGN KEY (agreement_id) REFERENCES agreements (id) ON DELETE CASCADE,
      FOREIGN KEY (source_clause_id) REFERENCES clauses (id) ON DELETE SET NULL
    );
  ''';

  static const String createScheduleRulesTable = '''
    CREATE TABLE schedule_rules (
      id TEXT PRIMARY KEY,
      obligation_id TEXT NOT NULL,
      recurrence_type TEXT NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT,
      cron_expression TEXT,
      FOREIGN KEY (obligation_id) REFERENCES obligations (id) ON DELETE CASCADE
    );
  ''';

  static const String createRemindersTable = '''
    CREATE TABLE reminders (
      id TEXT PRIMARY KEY,
      schedule_rule_id TEXT NOT NULL,
      due_at TEXT NOT NULL,
      status TEXT NOT NULL,
      snoozed_until TEXT,
      FOREIGN KEY (schedule_rule_id) REFERENCES schedule_rules (id) ON DELETE CASCADE
    );
  ''';

  static const String createRecordEntriesTable = '''
    CREATE TABLE record_entries (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL,
      agreement_id TEXT NOT NULL,
      agreement_version_id TEXT NOT NULL,
      obligation_id TEXT,
      source_clause_id TEXT,
      record_type TEXT NOT NULL,
      title TEXT NOT NULL,
      factual_description TEXT NOT NULL,
      occurred_at TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      timezone TEXT NOT NULL,
      created_by_party_id TEXT NOT NULL,
      corrects_record_entry_id TEXT,
      state TEXT NOT NULL,
      finalized_at TEXT,
      record_hash TEXT,
      previous_chain_hash TEXT,
      chain_hash TEXT,
      FOREIGN KEY (agreement_id) REFERENCES agreements (id) ON DELETE RESTRICT,
      FOREIGN KEY (agreement_version_id) REFERENCES agreement_versions (id) ON DELETE RESTRICT,
      FOREIGN KEY (obligation_id) REFERENCES obligations (id) ON DELETE SET NULL,
      FOREIGN KEY (source_clause_id) REFERENCES clauses (id) ON DELETE SET NULL,
      FOREIGN KEY (corrects_record_entry_id) REFERENCES record_entries (id) ON DELETE RESTRICT
    );
  ''';

  static const String createEvidenceAssetsTable = '''
    CREATE TABLE evidence_assets (
      id TEXT PRIMARY KEY,
      original_filename TEXT NOT NULL,
      mime_type TEXT NOT NULL,
      byte_size INTEGER NOT NULL,
      sha256 TEXT NOT NULL,
      capture_method TEXT NOT NULL,
      ingested_at TEXT NOT NULL,
      storage_identifier TEXT NOT NULL,
      asset_role TEXT NOT NULL,
      derived_from_evidence_id TEXT,
      FOREIGN KEY (derived_from_evidence_id) REFERENCES evidence_assets (id) ON DELETE SET NULL
    );
  ''';

  static const String createRecordEvidenceLinksTable = '''
    CREATE TABLE record_evidence_links (
      record_entry_id TEXT NOT NULL,
      evidence_asset_id TEXT NOT NULL,
      PRIMARY KEY (record_entry_id, evidence_asset_id),
      FOREIGN KEY (record_entry_id) REFERENCES record_entries (id) ON DELETE CASCADE,
      FOREIGN KEY (evidence_asset_id) REFERENCES evidence_assets (id) ON DELETE CASCADE
    );
  ''';

  static const String createExportPackagesTable = '''
    CREATE TABLE export_packages (
      id TEXT PRIMARY KEY,
      agreement_id TEXT NOT NULL,
      generated_at TEXT NOT NULL,
      package_sha256 TEXT NOT NULL,
      storage_identifier TEXT NOT NULL,
      FOREIGN KEY (agreement_id) REFERENCES agreements (id) ON DELETE CASCADE
    );
  ''';

  static const List<String> phase1Migration = [
    createAgreementsTable,
    createAgreementVersionsTable,
    createClausesTable,
    createObligationsTable,
    createScheduleRulesTable,
    createRemindersTable,
    createRecordEntriesTable,
    createEvidenceAssetsTable,
    createRecordEvidenceLinksTable,
    createExportPackagesTable,
  ];
}
