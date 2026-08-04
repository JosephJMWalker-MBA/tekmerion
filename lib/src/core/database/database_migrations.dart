import 'package:sqflite/sqflite.dart';
import 'database_schema.dart';

class DatabaseMigrations {
  /// Opens the database and runs migrations.
  static Future<Database> openAndMigrate(String path) async {
    return openDatabase(
      path,
      version: 2,
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
              'ALTER TABLE clauses ADD COLUMN parent_clause_id TEXT REFERENCES clauses (id) ON DELETE SET NULL');
          await db
              .execute('ALTER TABLE clauses ADD COLUMN parse_confidence REAL');
          await db.execute(
              'ALTER TABLE clauses ADD COLUMN created_at TEXT NOT NULL DEFAULT ""');
          await db.execute('ALTER TABLE clauses ADD COLUMN confirmed_at TEXT');

          // Add new indexes
          await db.execute(DatabaseSchema.indexClauseAgreementVersion);
          await db.execute(DatabaseSchema.indexClausePageRanges);
          await db.execute(DatabaseSchema.indexClauseReviewState);
        }
      },
    );
  }
}
