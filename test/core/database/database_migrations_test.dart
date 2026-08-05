import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekmerion/src/core/database/database_migrations.dart';
import 'package:tekmerion/src/core/database/database_schema.dart';

void main() {
  group('database_migrations', () {
    late String dbPath;
    late Database db;
    late Directory tempDir;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tek_db_migrations_');
      dbPath = p.join(tempDir.path, 'test.db');
    });

    tearDown(() async {
      if (db.isOpen) {
        await db.close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('fresh database creates all required tables', () async {
      db = await DatabaseMigrations.openAndMigrate(dbPath);

      final tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      final tableNames = tables.map((e) => e['name'] as String).toList();

      expect(
        tableNames,
        containsAll([
          'agreements',
          'agreement_versions',
          'clauses',
          'obligations',
          'schedule_rules',
          'reminders',
          'record_entries',
          'evidence_assets',
          'record_evidence_links',
          'export_packages',
        ]),
      );
    });

    test('migration version is recorded', () async {
      db = await DatabaseMigrations.openAndMigrate(dbPath);
      final version = await db.getVersion();
      expect(version, equals(5));
    });

    test('foreign keys are enforced', () async {
      db = await DatabaseMigrations.openAndMigrate(dbPath);

      // Enforce PRAGMA should be ON
      final res = await db.rawQuery('PRAGMA foreign_keys;');
      expect(res.first.values.first, equals(1));

      // Test foreign key constraint (inserting a version without an agreement)
      expect(
        () => db.insert('agreement_versions', {
          'id': 'v1',
          'agreement_id': 'missing_agreement',
          'source_evidence_asset_id': 'e1',
          'version_label': '1.0',
          'status': 'active',
          'imported_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Test ON DELETE RESTRICT for reminders -> obligations
      await db.insert('agreements', {
        'id': 'a1',
        'title': 'T',
        'agreement_type': 'lease',
        'status': 'active',
        'created_at': '2020',
      });
      await db.insert('obligations', {
        'id': 'o1',
        'agreement_id': 'a1',
        'source_type': 'contractual',
        'title': 'O',
        'description': 'D',
        'obligation_category': 'financial',
        'status': 'active',
        'created_at': '2020',
      });
      await db.insert('schedule_rules', {
        'id': 'sr1',
        'obligation_id': 'o1',
        'rule_type': 'oneTime',
        'timezone': 'UTC',
        'start_at': '2020',
        'lead_time_seconds': 0,
        'grace_period_seconds': 0,
        'confirmed_at': '2020',
      });
      await db.insert('reminders', {
        'id': 'r1',
        'agreement_id': 'a1',
        'obligation_id': 'o1',
        'schedule_rule_id': 'sr1',
        'occurrence_key': 'k1',
        'due_at': '2020',
        'remind_at': '2020',
        'timezone': 'UTC',
        'state': 'scheduled',
        'generation_version': 1,
        'generated_at': '2020',
        'notification_state': 'notRequested',
        'title': 'T',
        'body': 'B',
        'provenance_summary': 'P',
        'created_at': '2020',
        'updated_at': '2020',
      });

      // Deleting the obligation should fail because of RESTRICT
      await expectLater(
        () => db.delete('obligations', where: 'id = ?', whereArgs: ['o1']),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('database reopen preserves all data', () async {
      db = await DatabaseMigrations.openAndMigrate(dbPath);

      await db.insert('agreements', {
        'id': 'test1',
        'title': 'Test Agreement',
        'agreement_type': 'lease',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.close();

      db = await DatabaseMigrations.openAndMigrate(dbPath);
      final res = await db.query('agreements');
      expect(res.length, equals(1));
      expect(res.first['id'], equals('test1'));
    });
    test('v1 to v2 migration adds clause columns', () async {
      // Open as v1
      db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          // Re-create exactly as v1 (simulated by running only v1 migrations)
          for (final statement in DatabaseSchema.phase1Migration) {
            if (statement.contains('CREATE TABLE export_packages')) {
              continue;
            }
            if (statement.contains('CREATE TABLE clauses')) {
              await db.execute('''
                CREATE TABLE clauses (
                  id TEXT PRIMARY KEY,
                  agreement_version_id TEXT NOT NULL,
                  clause_number TEXT,
                  heading TEXT,
                  source_text TEXT NOT NULL,
                  normalized_text TEXT,
                  page_start INTEGER NOT NULL,
                  page_end INTEGER NOT NULL,
                  character_start INTEGER,
                  character_end INTEGER,
                  review_state TEXT NOT NULL,
                  FOREIGN KEY (agreement_version_id) REFERENCES agreement_versions (id) ON DELETE CASCADE
                );
              ''');
            } else if (statement.contains('CREATE TABLE obligations')) {
              await db.execute('''
                CREATE TABLE obligations (
                  id TEXT PRIMARY KEY,
                  agreement_id TEXT NOT NULL,
                  source_clause_id TEXT,
                  responsible_party_id TEXT,
                  title TEXT NOT NULL,
                  description TEXT NOT NULL,
                  obligation_category TEXT NOT NULL,
                  status TEXT NOT NULL,
                  confirmed_at TEXT NOT NULL,
                  superseded_by_obligation_id TEXT,
                  FOREIGN KEY (agreement_id) REFERENCES agreements (id) ON DELETE CASCADE,
                  FOREIGN KEY (source_clause_id) REFERENCES clauses (id) ON DELETE SET NULL,
                  FOREIGN KEY (superseded_by_obligation_id) REFERENCES obligations (id) ON DELETE SET NULL
                );
              ''');
            } else if (statement.contains('CREATE TABLE schedule_rules')) {
              await db.execute('''
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
                  confirmed_at TEXT NOT NULL
                );
              ''');
            } else if (statement.contains('CREATE TABLE reminders')) {
              await db.execute('''
                CREATE TABLE reminders (
                  id TEXT PRIMARY KEY,
                  obligation_id TEXT NOT NULL,
                  generated_from_rule_id TEXT,
                  scheduled_for TEXT NOT NULL,
                  state TEXT NOT NULL,
                  created_at TEXT NOT NULL,
                  completed_by_record_entry_id TEXT
                );
              ''');
            } else if (!statement.contains('idx_clause_') &&
                !statement.contains('idx_reminders_') &&
                !statement.contains('idx_obligation_reminders')) {
              await db.execute(statement);
            }
          }
        },
      );

      // Insert dummy clause in v1 format
      await db.insert('agreements', {
        'id': 'a1',
        'title': 'T',
        'agreement_type': 'lease',
        'status': 'active',
        'created_at': '2020',
      });
      await db.insert('evidence_assets', {
        'id': 'ev1',
        'original_filename': 'o.pdf',
        'sanitized_storage_filename': 'o.pdf',
        'mime_type': 'pdf',
        'byte_size': 1,
        'sha256': '1',
        'managed_storage_identifier': 'm1',
        'capture_method': 'inAppCapture',
        'asset_role': 'original',
        'imported_at': '2020',
        'pre_ingestion_history_status': 'unknown',
        'deletion_state': 'active',
      });
      await db.insert('agreement_versions', {
        'id': 'v1',
        'agreement_id': 'a1',
        'source_evidence_asset_id': 'ev1',
        'version_label': 'L',
        'status': 'active',
        'imported_at': '2020',
      });
      await db.insert('clauses', {
        'id': 'c1',
        'agreement_version_id': 'v1',
        'source_text': 'test',
        'page_start': 1,
        'page_end': 1,
        'review_state': 'draft',
      });

      await db.close();

      // Reopen and migrate to v2
      db = await DatabaseMigrations.openAndMigrate(dbPath);
      final res = await db.query('clauses');

      expect(res.length, equals(1));
      expect(res.first['id'], equals('c1'));
      expect(res.first.containsKey('created_at'), isTrue);
      expect(res.first['created_at'], equals(''));
      expect(res.first.containsKey('parent_clause_id'), isTrue);
      expect(res.first.containsKey('parse_confidence'), isTrue);
    });
    test('v4 to v5 migration preserves reminder data', () async {
      // Open as v4
      db = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
          // Re-create exactly as v4
          for (final statement in DatabaseSchema.phase1Migration) {
            if (statement.contains('CREATE TABLE reminders')) {
              await db.execute('''
                CREATE TABLE reminders (
                  id TEXT PRIMARY KEY,
                  obligation_id TEXT NOT NULL,
                  generated_from_rule_id TEXT,
                  scheduled_for TEXT NOT NULL,
                  state TEXT NOT NULL,
                  created_at TEXT NOT NULL,
                  completed_by_record_entry_id TEXT,
                  FOREIGN KEY (obligation_id) REFERENCES obligations (id) ON DELETE CASCADE
                );
              ''');
            } else if (!statement.contains('idx_reminders_') &&
                !statement.contains('idx_obligation_reminders')) {
              try {
                await db.execute(statement);
              } catch (_) {}
            }
          }
        },
      );

      await db.insert('agreements', {
        'id': 'a1',
        'title': 'T',
        'agreement_type': 'lease',
        'status': 'active',
        'created_at': '2020',
      });
      await db.insert('agreements', {
        'id': 'a2',
        'title': 'T2',
        'agreement_type': 'lease',
        'status': 'active',
        'created_at': '2020',
      });
      await db.insert('obligations', {
        'id': 'o1',
        'agreement_id': 'a1',
        'source_type': 'contractual',
        'title': 'O1',
        'description': 'D',
        'obligation_category': 'financial',
        'status': 'active',
        'created_at': '2020',
      });
      await db.insert('obligations', {
        'id': 'o2',
        'agreement_id': 'a2',
        'source_type': 'contractual',
        'title': 'O2',
        'description': 'D',
        'obligation_category': 'financial',
        'status': 'active',
        'created_at': '2020',
      });

      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert('reminders', {
        'id': 'r_scheduled',
        'obligation_id': 'o1',
        'scheduled_for': now,
        'state': 'scheduled',
        'created_at': now,
      });
      await db.insert('reminders', {
        'id': 'r_due',
        'obligation_id': 'o1',
        'scheduled_for': now,
        'state': 'due',
        'created_at': now,
      });
      await db.insert('reminders', {
        'id': 'r_acknowledged',
        'obligation_id': 'o2',
        'scheduled_for': now,
        'state': 'acknowledged',
        'created_at': now,
      });
      await db.insert('reminders', {
        'id': 'r_completed',
        'obligation_id': 'o2',
        'scheduled_for': now,
        'state': 'completed',
        'created_at': now,
      });
      await db.insert('reminders', {
        'id': 'r_dismissed',
        'obligation_id': 'o2',
        'scheduled_for': now,
        'state': 'dismissed',
        'created_at': now,
      });

      await db.close();

      // Reopen and migrate to v5
      db = await DatabaseMigrations.openAndMigrate(dbPath);

      // Verify data is migrated
      final res = await db.query('reminders', orderBy: 'id');
      expect(res.length, equals(5));

      final byId = {for (final r in res) r['id']: r};

      expect(byId['r_scheduled']!['state'], equals('scheduled'));
      expect(byId['r_scheduled']!['agreement_id'], equals('a1'));
      expect(
          byId['r_scheduled']!['notification_state'], equals('notRequested'),);

      expect(byId['r_due']!['state'],
          equals('scheduled'),); // 'due' maps to 'scheduled'

      expect(byId['r_acknowledged']!['state'], equals('acknowledged'));
      expect(byId['r_completed']!['state'], equals('completed'));
      expect(byId['r_dismissed']!['state'], equals('dismissed'));

      for (final r in res) {
        expect(r['schedule_rule_id'], isNotNull);
        expect(r['occurrence_key'], isNotNull);
        expect(r['created_at'], isNotNull);
      }
    });

    test('v4 to v5 migration rollback on constraint violation', () async {
      // Open as v4
      db = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
          for (final statement in DatabaseSchema.phase1Migration) {
            if (statement.contains('CREATE TABLE reminders')) {
              await db.execute('''
                CREATE TABLE reminders (
                  id TEXT PRIMARY KEY,
                  obligation_id TEXT NOT NULL,
                  generated_from_rule_id TEXT,
                  scheduled_for TEXT NOT NULL,
                  state TEXT NOT NULL,
                  created_at TEXT NOT NULL,
                  completed_by_record_entry_id TEXT,
                  FOREIGN KEY (obligation_id) REFERENCES obligations (id) ON DELETE CASCADE
                );
              ''');
            } else if (!statement.contains('idx_reminders_') &&
                !statement.contains('idx_obligation_reminders')) {
              try {
                await db.execute(statement);
              } catch (_) {}
            }
          }
        },
      );

      await db.insert('agreements', {
        'id': 'a1',
        'title': 'T',
        'agreement_type': 'lease',
        'status': 'active',
        'created_at': '2020',
      });
      await db.insert('obligations', {
        'id': 'o1',
        'agreement_id': 'a1',
        'source_type': 'contractual',
        'title': 'O',
        'description': 'D',
        'obligation_category': 'financial',
        'status': 'active',
        'created_at': '2020',
      });
      await db.insert('reminders', {
        'id': 'r1',
        'obligation_id': 'o1',
        'scheduled_for': '2020',
        'state': 'scheduled',
        'created_at': '2020',
      });

      // Inject a bad state that violates v5 check constraints and will cause migration to throw.
      // v5 check constraint: state IN ('scheduled', 'acknowledged', 'dismissed', 'completed', 'cancelled', 'superseded', 'expired')
      // Note: 'due' is remapped in our INSERT SELECT, but an unknown state will fail the constraint.
      await db.insert('reminders', {
        'id': 'r2',
        'obligation_id': 'o1',
        'scheduled_for': '2020',
        'state': 'INVALID_STATE',
        'created_at': '2020',
      });

      await db.close();

      // Migrate
      await expectLater(
        () => DatabaseMigrations.openAndMigrate(dbPath),
        throwsException,
      );

      // Verify db is still v4 and reminders table has original rows
      db = await openDatabase(dbPath);
      final version = await db.getVersion();
      expect(version, equals(4));

      final res = await db.query('reminders', orderBy: 'id');
      expect(res.length, equals(2));
      expect(res[0]['id'], equals('r1'));
      expect(res[0]['state'], equals('scheduled'));
      expect(res[1]['id'], equals('r2'));
      expect(res[1]['state'], equals('INVALID_STATE'));
    });
  });
}
