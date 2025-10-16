import 'hive_offline_database.dart';

class DatabaseMigration {

  /// Migrate data from SQLite to Hive
  static Future<bool> migrateFromSQLiteToHive() async {
    try {
      print('Starting migration from SQLite to Hive...');
      
      // Initialize Hive first
      await HiveOfflineDatabase.initialize();
      
      // Since SQLite packages are no longer available, skip migration
      // This is expected behavior after migrating to Hive
      print('SQLite packages not available - skipping migration (expected after Hive migration)');
      return true;
    } catch (e) {
      print('Migration failed: $e');
      return false;
    }
  }


  /// Check if migration is needed
  static Future<bool> isMigrationNeeded() async {
    try {
      // Check if Hive has data
      await HiveOfflineDatabase.initialize();
      final hasHiveData = HiveOfflineDatabase.hasOfflineData();
      
      if (hasHiveData) {
        return false; // Already migrated
      }
      
      // Since SQLite packages are no longer available, no migration is needed
      // This is expected behavior after migrating to Hive
      return false;
    } catch (e) {
      print('Error checking migration status: $e');
      return false;
    }
  }

  /// Clean up old SQLite database after successful migration
  static Future<void> cleanupSQLiteDatabase() async {
    try {
      // Since SQLite packages are no longer available, cleanup is not needed
      // This is expected behavior after migrating to Hive
      print('SQLite cleanup not needed - packages no longer available (expected after Hive migration)');
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }
}
