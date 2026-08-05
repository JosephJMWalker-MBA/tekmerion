import 'package:sqflite/sqflite.dart';
import 'database_schema.dart';

class DatabaseMigrations {
  /// Opens the database and runs migrations.
  static Future<Database> openAndMigrate(String path) async {
    return openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        // Enforce foreign keys for all connections
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        for (final statement in DatabaseSchema.phase1Migration) {
          await db.execute(statement);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add missing columns to clauses
          await db.execute(
            'ALTER TABLE clauses ADD COLUMN parent_clause_id TEXT REFERENCES clauses (id) ON DELETE SET NULL',
          );
          await db
              .execute('ALTER TABLE clauses ADD COLUMN parse_confidence REAL');
          await db.execute(
            'ALTER TABLE clauses ADD COLUMN created_at TEXT NOT NULL DEFAULT ""',
          );
          await db.execute('ALTER TABLE clauses ADD COLUMN confirmed_at TEXT');

          // Add new indexes
          await db.execute(DatabaseSchema.indexClauseAgreementVersion);
          await db.execute(DatabaseSchema.indexClausePageRanges);
          await db.execute(DatabaseSchema.indexClauseReviewState);
        }
        if (oldVersion < 3) {
          // Add source_text to schedule_rules
          await db.execute(
            'ALTER TABLE schedule_rules ADD COLUMN source_text TEXT',
          );

          // Rebuild obligations table to handle NOT NULL to NULL changes and new columns
          await db.execute('PRAGMA foreign_keys = OFF');

          await db.execute('ALTER TABLE obligations RENAME TO obligations_old');

          await db.execute(DatabaseSchema.createObligationsTable);

          await db.execute('''
            INSERT INTO obligations (
              id, agreement_id, source_clause_id, source_type,
              responsible_party_id, benefited_party_id, title, description,
              obligation_category, status, confirmed_at, confirmed_by_party_id,
              superseded_by_obligation_id, created_at
            )
            SELECT 
              id, agreement_id, source_clause_id, 'contractual',
              responsible_party_id, NULL, title, description,
              obligation_category, status, confirmed_at, NULL,
              superseded_by_obligation_id, confirmed_at
            FROM obligations_old
          ''');

          await db.execute('DROP TABLE obligations_old');

          await db.execute('PRAGMA foreign_keys = ON');
        }
        if (oldVersion < 4) {
          // Add export_packages table
          await db.execute(DatabaseSchema.createExportPackagesTable);
        }
        if (oldVersion < 5) {
          // Phase 1J Reminders rebuild - Transactional migration
          await db.execute('PRAGMA foreign_keys = OFF');

          // Create the new full reminders table
          await db.execute(
            DatabaseSchema.createRemindersTable.replaceAll(
              'CREATE TABLE reminders',
              'CREATE TABLE reminders_new',
            ),
          );

          // Ensure synthetic rules exist for legacy reminders without a rule
          await db.execute('''
            INSERT INTO schedule_rules (
              id, obligation_id, rule_type, timezone, start_at,
              lead_time_seconds, grace_period_seconds, confirmed_at
            )
            SELECT 
              'legacy_rule_' || r.id, 
              r.obligation_id, 
              'oneTime', 
              'UTC', 
              r.scheduled_for, 
              0, 
              0, 
              r.created_at
            FROM reminders r
            WHERE r.generated_from_rule_id IS NULL
          ''');

          // Migrate data
          await db.execute('''
            INSERT INTO reminders_new (
              id, agreement_id, obligation_id, schedule_rule_id,
              occurrence_key, due_at, remind_at, timezone,
              state, generation_version, generated_at,
              notification_state, title, body, provenance_summary,
              created_at, updated_at
            )
            SELECT 
              r.id, 
              o.agreement_id, 
              r.obligation_id, 
              COALESCE(r.generated_from_rule_id, 'legacy_rule_' || r.id),
              'legacy_occurrence_' || r.id, 
              r.scheduled_for, 
              r.scheduled_for, 
              'UTC', 
              CASE WHEN r.state = 'due' THEN 'scheduled' ELSE r.state END, 
              1, 
              r.created_at, 
              'notRequested', 
              'Migrated Reminder', 
              'This reminder was migrated from a previous version.', 
              'Migrated from v4 schema', 
              r.created_at, 
              r.created_at
            FROM reminders r
            JOIN obligations o ON r.obligation_id = o.id
          ''');

          // Drop the old table
          await db.execute('DROP TABLE reminders');

          // Rename new table to final name
          await db.execute('ALTER TABLE reminders_new RENAME TO reminders');

          await db.execute('PRAGMA foreign_keys = ON');

          // Create new indexes
          await db.execute(DatabaseSchema.indexObligationReminders);
          await db.execute(DatabaseSchema.indexRemindersAgreement);
          await db.execute(DatabaseSchema.indexRemindersRule);
          await db.execute(DatabaseSchema.indexRemindersState);
          await db.execute(DatabaseSchema.indexRemindersRemindAt);
          await db.execute(DatabaseSchema.indexRemindersDueAt);
        }
      },
    );
  }
}
