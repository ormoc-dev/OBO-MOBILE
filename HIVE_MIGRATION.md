# Hive Database Migration Guide

This document explains the migration from SQLite to Hive for offline storage in the OBO Mobile app.

## What Changed

### Dependencies Updated
- **Removed**: `sqflite`, `sqflite_common_ffi`
- **Added**: `hive`, `hive_flutter`, `hive_generator`, `path_provider`

### New Files Created
- `lib/services/hive_offline_database.dart` - New Hive-based database service
- `lib/services/database_migration.dart` - Migration helper from SQLite to Hive

### Updated Files
- `lib/models/user.dart` - Added Hive annotations
- `lib/models/assignment.dart` - Added Hive annotations
- `lib/services/offline_storage.dart` - Updated to use Hive for mobile
- `lib/main.dart` - Added database initialization and migration
- `pubspec.yaml` - Updated dependencies

## Benefits of Hive over SQLite

1. **Better Performance** - Faster read/write operations
2. **Cross-platform** - Works seamlessly on mobile, web, and desktop
3. **No Native Dependencies** - Pure Dart implementation
4. **Type-safe** - Better integration with Dart's type system
5. **Simpler API** - Easier to use than SQLite
6. **Better for Flutter** - Designed specifically for Flutter/Dart

## How to Use

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Generate Hive Adapters
```bash
flutter packages pub run build_runner build
```

### 3. Database Initialization
The database is automatically initialized in `main.dart` with migration support:

```dart
// Automatic migration from SQLite to Hive
await _initializeDatabase();
```

### 4. Using the Database

#### Save User
```dart
final user = User(id: 1, name: 'John Doe', role: 'inspector');
await HiveOfflineDatabase.saveUser(user);
```

#### Get Current User
```dart
final user = HiveOfflineDatabase.getCurrentUser();
```

#### Save Assignments
```dart
final assignments = [assignment1, assignment2, assignment3];
await HiveOfflineDatabase.saveAssignments(assignments);
```

#### Get Assignments
```dart
// Get all assignments
final allAssignments = HiveOfflineDatabase.getAssignments();

// Get assignments by status
final pendingAssignments = HiveOfflineDatabase.getAssignments(status: 'assigned');
```

#### Get Statistics
```dart
final stats = HiveOfflineDatabase.getAssignmentStatistics();
print('Total assignments: ${stats.totalAssignments}');
```

### 5. Migration Process

The app automatically handles migration from SQLite to Hive:

1. **Check for existing SQLite data** - If found, migration is needed
2. **Migrate data** - Users, assignments, and sync status are migrated
3. **Initialize Hive** - New database is ready to use
4. **Optional cleanup** - Old SQLite database can be removed

## Database Structure

### Hive Boxes
- `users` - Stores current user data
- `assignments` - Stores assignment data (keyed by assignment_id)
- `sync_status` - Stores sync status information

### Data Models
All models now have Hive annotations:
- `@HiveType(typeId: 0)` for User
- `@HiveType(typeId: 1)` for Assignment
- `@HiveType(typeId: 2)` for AssignmentStatistics

## Troubleshooting

### Common Issues

1. **Build Runner Errors**
   ```bash
   flutter clean
   flutter pub get
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```

2. **Migration Issues**
   - Check console logs for migration status
   - If migration fails, the app continues with a fresh Hive database
   - Old SQLite data remains untouched for manual recovery

3. **Performance Issues**
   - Hive is generally faster than SQLite
   - If you experience issues, check for proper box initialization

### Debug Information

The app provides debug information about the database:
```dart
final info = HiveOfflineDatabase.getDatabaseInfo();
print('Database info: $info');
```

## Migration Checklist

- [x] Update dependencies in `pubspec.yaml`
- [x] Add Hive annotations to models
- [x] Create Hive database service
- [x] Create migration helper
- [x] Update main.dart for initialization
- [x] Update offline storage service
- [ ] Run `flutter packages pub run build_runner build`
- [ ] Test the migration process
- [ ] Test all database operations
- [ ] Remove old SQLite database (optional)

## Next Steps

1. Run the build runner to generate Hive adapters
2. Test the app to ensure migration works correctly
3. Verify all offline functionality works as expected
4. Consider removing the old SQLite database files after successful migration

## Support

If you encounter any issues with the migration:
1. Check the console logs for error messages
2. Verify all dependencies are properly installed
3. Ensure build runner has generated the necessary files
4. Test with a fresh app installation to verify the new database works


