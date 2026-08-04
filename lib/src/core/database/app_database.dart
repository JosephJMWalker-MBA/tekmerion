import 'package:sqflite/sqflite.dart';
import 'database_migrations.dart';

class AppDatabase {
  AppDatabase._();

  static Database? _database;

  /// Initializes the database at the given path.
  static Future<Database> init(String path) async {
    if (_database != null) {
      return _database!;
    }
    _database = await DatabaseMigrations.openAndMigrate(path);
    return _database!;
  }

  /// Closes the active database connection.
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Exposes the active database instance.
  static Database get instance {
    if (_database == null) {
      throw StateError(
        'Database not initialized. Call AppDatabase.init() first.',
      );
    }
    return _database!;
  }
}
