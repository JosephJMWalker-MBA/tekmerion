class DatabaseSchema {
  static const String createAgreementsTable = '''
    CREATE TABLE agreements (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      agreement_type TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      archived_at TEXT
    );
  ''';

  static const String createAgreementVersionsTable = '''
    CREATE TABLE agreement_versions (
      id TEXT PRIMARY KEY,
      agreement_id TEXT NOT NULL,
      source_evidence_asset_id TEXT NOT NULL,
      version_label TEXT NOT NULL,
      effective_from TEXT,
      effective_to TEXT,
      status TEXT NOT NULL,
      imported_at TEXT NOT NULL,
      supersedes_version_id TEXT,
      FOREIGN KEY (agreement_id) REFERENCES agreements (id) ON DELETE CASCADE
    );
  ''';

  static const String createClausesTable = '''
    CREATE TABLE clauses (
      id TEXT PRIMARY KEY,
      agreement_version_id TEXT NOT NULL,
      parent_clause_id TEXT,
      clause_number TEXT,
      heading TEXT,
      source_text TEXT NOT NULL,
      normalized_text TEXT,
      page_start INTEGER NOT NULL,
      page_end INTEGER NOT NULL,
      character_start INTEGER,
      character_end INTEGER,
      parse_confidence REAL,
      review_state TEXT NOT NULL,
      created_at TEXT NOT NULL,
      confirmed_at TEXT,
      FOREIGN KEY (agreement_version_id) REFERENCES agreement_versions (id) ON DELETE CASCADE,
      FOREIGN KEY (parent_clause_id) REFERENCES clauses (id) ON DELETE SET NULL
    );
  ''';

  static const String createObligationsTable = '''
    CREATE TABLE obligations (
      id TEXT PRIMARY KEY,
      agreement_id TEXT NOT NULL,
      source_clause_id TEXT,
      source_type TEXT NOT NULL,
      responsible_party_id TEXT,
      benefited_party_id TEXT,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      obligation_category TEXT NOT NULL,
      status TEXT NOT NULL,
      confirmed_at TEXT,
      confirmed_by_party_id TEXT,
      superseded_by_obligation_id TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (agreement_id) REFERENCES agreements (id) ON DELETE CASCADE,
      FOREIGN KEY (source_clause_id) REFERENCES clauses (id) ON DELETE SET NULL,
      FOREIGN KEY (superseded_by_obligation_id) REFERENCES obligations (id) ON DELETE SET NULL
    );
  ''';

  static const String createScheduleRulesTable = '''
    CREATE TABLE schedule_rules (
      id TEXT PRIMARY KEY,
      obligation_id TEXT NOT NULL,
      rule_type TEXT NOT NULL,
      timezone TEXT NOT NULL,
      start_at TEXT NOT NULL,
      end_at TEXT,
      recurrence_expression TEXT,
      lead_time_seconds INTEGER NOT NULL,
      grace_period_seconds INTEGER NOT NULL,
      source_text TEXT,
      confirmed_at TEXT NOT NULL,
      FOREIGN KEY (obligation_id) REFERENCES obligations (id) ON DELETE CASCADE
    );
  ''';

  static const String createRemindersTable = '''
    CREATE TABLE reminders (
      id TEXT PRIMARY KEY,
      obligation_id TEXT NOT NULL,
      generated_from_rule_id TEXT,
      scheduled_for TEXT NOT NULL,
      state TEXT NOT NULL,
      created_at TEXT NOT NULL,
      completed_by_record_entry_id TEXT,
      FOREIGN KEY (obligation_id) REFERENCES obligations (id) ON DELETE CASCADE,
      FOREIGN KEY (generated_from_rule_id) REFERENCES schedule_rules (id) ON DELETE SET NULL,
      FOREIGN KEY (completed_by_record_entry_id) REFERENCES record_entries (id) ON DELETE SET NULL
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
      interpretation_text TEXT,
      occurred_at TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      timezone TEXT NOT NULL,
      created_by_party_id TEXT NOT NULL,
      corrects_record_entry_id TEXT,
      
      -- Persistence specific fields
      state TEXT NOT NULL,
      canonicalization_version TEXT NOT NULL,
      record_hash TEXT,
      previous_chain_hash TEXT,
      chain_hash TEXT,
      signature_state TEXT NOT NULL,
      finalized_at TEXT,

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
      sanitized_storage_filename TEXT NOT NULL,
      mime_type TEXT NOT NULL,
      byte_size INTEGER NOT NULL,
      sha256 TEXT NOT NULL,
      managed_storage_identifier TEXT NOT NULL,
      capture_method TEXT NOT NULL,
      asset_role TEXT NOT NULL,
      derived_from_evidence_id TEXT,
      imported_at TEXT NOT NULL,
      captured_at TEXT,
      pre_ingestion_history_status TEXT NOT NULL,
      deletion_state TEXT NOT NULL,
      FOREIGN KEY (derived_from_evidence_id) REFERENCES evidence_assets (id) ON DELETE SET NULL
    );
  ''';

  static const String createRecordEvidenceLinksTable = '''
    CREATE TABLE record_evidence_links (
      id TEXT PRIMARY KEY,
      record_entry_id TEXT NOT NULL,
      evidence_asset_id TEXT NOT NULL,
      relationship_type TEXT NOT NULL,
      caption TEXT,
      display_order INTEGER NOT NULL,
      FOREIGN KEY (record_entry_id) REFERENCES record_entries (id) ON DELETE CASCADE,
      FOREIGN KEY (evidence_asset_id) REFERENCES evidence_assets (id) ON DELETE CASCADE
    );
  ''';

  static const String createExportPackagesTable = '''
    CREATE TABLE export_packages (
      id TEXT PRIMARY KEY,
      agreement_id TEXT NOT NULL,
      generated_at TEXT NOT NULL,
      format TEXT NOT NULL,
      filter_parameters_json TEXT NOT NULL,
      manifest_sha256 TEXT NOT NULL,
      managed_storage_identifier TEXT NOT NULL,
      generator_version TEXT NOT NULL,
      FOREIGN KEY (agreement_id) REFERENCES agreements (id) ON DELETE CASCADE
    );
  ''';

  // Indexes
  static const String indexRecordTimeline = '''
    CREATE INDEX idx_record_timeline ON record_entries (agreement_id, recorded_at);
  ''';

  static const String indexObligationReminders = '''
    CREATE INDEX idx_obligation_reminders ON reminders (obligation_id, scheduled_for);
  ''';

  static const String indexEvidenceHashLookup = '''
    CREATE INDEX idx_evidence_hash ON evidence_assets (sha256);
  ''';

  static const String indexCorrectionRelationships = '''
    CREATE INDEX idx_record_corrections ON record_entries (corrects_record_entry_id);
  ''';

  static const String indexChainOrdering = '''
    CREATE INDEX idx_record_chain ON record_entries (agreement_id, chain_hash);
  ''';

  static const String indexClauseAgreementVersion = '''
    CREATE INDEX idx_clause_agreement_version ON clauses (agreement_version_id);
  ''';

  static const String indexClausePageRanges = '''
    CREATE INDEX idx_clause_page_ranges ON clauses (page_start, page_end);
  ''';

  static const String indexClauseReviewState = '''
    CREATE INDEX idx_clause_review_state ON clauses (review_state);
  ''';

  static const List<String> phase1Migration = [
    createAgreementsTable,
    createAgreementVersionsTable,
    createClausesTable,
    createObligationsTable,
    createScheduleRulesTable,
    createRecordEntriesTable, // Record entries must exist before reminders due to foreign key
    createRemindersTable,
    createEvidenceAssetsTable,
    createRecordEvidenceLinksTable,
    createExportPackagesTable,
    indexRecordTimeline,
    indexObligationReminders,
    indexEvidenceHashLookup,
    indexCorrectionRelationships,
    indexChainOrdering,
    indexClauseAgreementVersion,
    indexClausePageRanges,
    indexClauseReviewState,
  ];
}
