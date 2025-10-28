# OBO Mobile - Flutter App Documentation

This is the complete documentation for the OBO Mobile Flutter application that connects to the OBO-LGU PHP backend system.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [API Setup & Configuration](#api-setup--configuration)
3. [Integration Summary](#integration-summary)
4. [Offline Login Flow](#offline-login-flow)
5. [Hive Database Migration](#hive-database-migration)
6. [API Endpoint Requirements](#api-endpoint-requirements)
7. [Asset Management & Icon Setup](#asset-management--icon-setup)
8. [Testing Guide](#testing-guide)

---

## Getting Started

A new Flutter project.

### Resources

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev/), which offers tutorials, samples, guidance on mobile development, and a full API reference.

---

## API Setup & Configuration

This guide will help you connect your Flutter app to your PHP API running on XAMPP.

### Prerequisites

1. XAMPP server running with your PHP API
2. Flutter development environment set up
3. Your PHP API accessible at `http://localhost/OBO-LGU/api/auth/login.php`

### Step 1: Install Dependencies

Run the following command in your Flutter project directory:

```bash
flutter pub get
```

### Step 2: Configure API URL

1. Open `lib/config/app_config.dart`
2. Update the `baseUrl` based on your testing environment:

#### For Android Emulator:
```dart
static const String baseUrl = 'http://10.0.2.2/OBO-LGU/api';
```

#### For Physical Device:
1. Find your computer's IP address:
   - Windows: Run `ipconfig` in Command Prompt
   - Mac/Linux: Run `ifconfig` in Terminal
2. Update the URL:
```dart
static const String baseUrl = 'http://YOUR_IP_ADDRESS/OBO-LGU/api';
```

#### For Web Development:
```dart
static const String baseUrl = 'http://localhost/OBO-LGU/api';
```

### Step 3: Test API Connection

1. Make sure XAMPP is running
2. Test your API endpoint in a browser: `http://localhost/OBO-LGU/api/auth/login.php`
3. You should see a JSON response indicating the method is not allowed (since it's a POST endpoint)

### Step 4: Run the Flutter App

```bash
flutter run
```

### Step 5: Test Login

1. Use the login credentials from your database
2. The app should successfully authenticate and redirect to the dashboard

### Troubleshooting

#### Common Issues:

1. **Connection Refused Error:**
   - Check if XAMPP is running
   - Verify the API URL in `app_config.dart`
   - Ensure your device/emulator can reach the server

2. **CORS Issues:**
   - Your PHP API already has CORS headers configured
   - If you encounter CORS issues, check the headers in `login.php`

3. **Network Security Policy (Android):**
   - Add network security config if needed
   - Check `android/app/src/main/AndroidManifest.xml`

4. **iOS Network Issues:**
   - Add App Transport Security settings in `ios/Runner/Info.plist`

#### Testing API Endpoints:

You can test your API using tools like Postman or curl:

```bash
curl -X POST http://localhost/OBO-LGU/api/auth/login.php \
  -H "Content-Type: application/json" \
  -d '{"username":"your_username","password":"your_password","remember":false}'
```

### File Structure

```
lib/
├── config/
│   └── app_config.dart          # API configuration
├── models/
│   └── user.dart               # User data models
├── services/
│   ├── api_service.dart        # HTTP client service
│   └── auth_service.dart       # Authentication service
├── screens/
│   └── dashboard_screen.dart   # Dashboard after login
└── main.dart                   # Main app with auth wrapper
```

### Features Implemented

- ✅ User authentication with PHP API
- ✅ Session management with local storage
- ✅ Remember me functionality
- ✅ Automatic login check on app start
- ✅ Dashboard with user information
- ✅ Logout functionality
- ✅ Error handling and user feedback
- ✅ Loading states and UI feedback

### Next Steps

1. Add more API endpoints as needed
2. Implement additional features like:
   - User profile management
   - Application forms
   - Inspection scheduling
   - Report generation
3. Add push notifications
4. Implement offline functionality
5. Add biometric authentication

### Security Notes

- The current implementation stores user data locally
- Consider implementing token-based authentication
- Add proper error handling for production
- Implement proper session timeout
- Consider adding certificate pinning for production

---

## Integration Summary

### Flutter-PHP API Integration Complete ✅

Your Flutter app is now successfully connected to your PHP API!

### 🚀 Features Implemented

#### 1. **Authentication System**
- ✅ Login with username/password
- ✅ Session management with local storage
- ✅ Remember me functionality
- ✅ Automatic login check on app start
- ✅ Secure logout with session cleanup

#### 2. **API Integration**
- ✅ HTTP client service for API communication
- ✅ JSON serialization/deserialization
- ✅ Error handling and network connectivity checks
- ✅ CORS-compatible headers

#### 3. **User Interface**
- ✅ Beautiful neumorphic design
- ✅ Login screen with form validation
- ✅ Dashboard with user information
- ✅ Loading states and user feedback
- ✅ Debug screen for testing connections

#### 4. **Data Models**
- ✅ User model with role information
- ✅ Login request/response models
- ✅ JSON serialization support

### 📁 File Structure Created

```
lib/
├── config/
│   └── app_config.dart          # API configuration
├── models/
│   ├── user.dart               # User data models
│   └── user.g.dart             # Generated JSON serialization
├── services/
│   ├── api_service.dart        # HTTP client service
│   └── auth_service.dart       # Authentication service
├── screens/
│   ├── dashboard_screen.dart   # Dashboard after login
│   └── debug_screen.dart       # Debug and setup screen
├── utils/
│   └── network_utils.dart      # Network utility functions
└── main.dart                   # Main app with auth wrapper
```

### 🔧 Configuration Required

#### 1. **Update API URL**
Edit `lib/config/app_config.dart` and update the `baseUrl`:

```dart
// For Android emulator
static const String baseUrl = 'http://10.0.2.2/OBO-LGU/api';

// For physical device (replace with your IP)
static const String baseUrl = 'http://192.168.1.100/OBO-LGU/api';
```

#### 2. **Find Your IP Address**
- **Windows**: Run `ipconfig` in Command Prompt
- **Mac/Linux**: Run `ifconfig` in Terminal
- Look for your local network IP (usually starts with 192.168.x.x)

### 🧪 Testing Your Integration

#### 1. **Run the App**
```bash
cd OBO-MOBILE
flutter run
```

#### 2. **Test Connection**
1. Tap "Debug & Setup" on the welcome screen
2. Tap "Test API Connection"
3. Should show "API server is reachable ✅"

#### 3. **Test Login**
1. Use valid credentials from your database
2. Should successfully login and show dashboard
3. User information should display correctly

### 🔐 Security Features

- ✅ Password validation
- ✅ Session timeout handling
- ✅ Secure token storage
- ✅ Input sanitization
- ✅ CORS headers configured

### 🎯 Next Steps

#### Immediate Actions:
1. **Update the API URL** in `app_config.dart`
2. **Test the connection** using the debug screen
3. **Verify login** with your database credentials

#### Future Enhancements:
1. Add more API endpoints (applications, inspections, etc.)
2. Implement push notifications
3. Add offline functionality
4. Implement biometric authentication
5. Add user profile management

### 🐛 Troubleshooting

#### Common Issues:

1. **"Connection refused" error:**
   - Check if XAMPP is running
   - Verify the API URL is correct
   - Ensure device can reach the server

2. **"API server not reachable":**
   - Check your IP address
   - Verify firewall settings
   - Test API in browser first

3. **Login fails:**
   - Check database credentials
   - Verify API endpoint is working
   - Check network connectivity

#### Debug Tools:
- Use the "Debug & Setup" screen to test connections
- Check console logs for detailed error messages
- Test API endpoints directly in browser/Postman

### 📱 Supported Platforms

- ✅ Android (emulator and physical device)
- ✅ iOS (simulator and physical device)
- ✅ Web (for development/testing)

### 🎉 Success Indicators

Your integration is working when:
- ✅ Debug screen shows "API server is reachable"
- ✅ Login succeeds with valid credentials
- ✅ Dashboard displays user information
- ✅ Logout works and returns to welcome screen
- ✅ App remembers login (if "Remember me" was checked)

### 📞 Support

If you encounter any issues:
1. Check the debug screen first
2. Verify your XAMPP server is running
3. Test the API endpoint in a browser
4. Check the console logs for error messages

Your Flutter app is now ready to communicate with your PHP API! 🚀

---

## Offline Login Flow

### How Offline Login Works

#### 1. Initial Setup (Online)
```
User Login → Sync Data → Store Credentials + Assignments
```

#### 2. Offline Login Process
```
App Launch → Check Internet → No Internet → Use Offline Login
```

### Detailed Flow

#### Step 1: User Syncs Data (Online)
1. User logs in with username/password
2. User clicks "Sync My Data" in dashboard
3. App fetches user's assignments from server
4. App stores:
   - User assignments in Hive database
   - User credentials in SharedPreferences
   - Sync timestamp

#### Step 2: User Goes Offline
1. User closes app or loses internet connection
2. User reopens app later (offline)

#### Step 3: Offline Login
1. App detects no internet connection
2. App shows login screen
3. User enters their username (password optional for offline)
4. App checks stored credentials:
   - If username matches stored credentials → Login successful
   - If no match → Show error message

#### Step 4: Offline Access
1. User can view their synced assignments
2. User can update assignment status
3. Changes are stored locally
4. When online again, changes can be synced back

### Security Features

#### What's Stored
- ✅ Username
- ✅ User ID
- ✅ Inspector Role ID
- ✅ User Role
- ✅ User Status
- ✅ Sync Timestamp

#### What's NOT Stored
- ❌ Password (never stored)
- ❌ Other users' data
- ❌ Sensitive server tokens

#### Security Measures
- Credentials stored in encrypted device storage
- Only accessible to the app
- Automatically cleared on logout
- User can manually clear all data

### User Experience

#### Online Flow
```
Login → Dashboard → Sync My Data → Ready for Offline
```

#### Offline Flow
```
App Launch → Login Screen → Enter Username → Access Assignments
```

#### Benefits
- 🔒 **Secure**: No passwords stored
- ⚡ **Fast**: Instant offline login
- 📱 **Convenient**: Works without internet
- 🔄 **Reliable**: Data persists between sessions

### Error Handling

#### Common Scenarios
1. **No Offline Data**: User must sync first when online
2. **Wrong Username**: Only synced user can login offline
3. **Expired Data**: User should re-sync when online
4. **Corrupted Data**: User can clear and re-sync

#### User Messages
- "No offline data available. Please connect to internet and sync first."
- "Username not found in offline data. Please sync your data first."
- "Offline login successful. You can now access your assignments."

### Implementation Notes

#### Files Modified
- `offline_sync_service.dart` - Added credential storage
- `auth_service.dart` - Enhanced offline authentication
- `dashboard_screen.dart` - Updated sync functionality
- `debug_screen.dart` - Added offline status display

#### API Requirements
- New endpoint: `/mobile/get_user_assignments.php`
- Returns user-specific assignments
- Requires authentication
- Filters by inspector_role_id

#### Database Changes
- Uses Hive for offline storage
- SharedPreferences for credentials
- Automatic cleanup on logout

---

## Hive Database Migration

This document explains the migration from SQLite to Hive for offline storage in the OBO Mobile app.

### What Changed

#### Dependencies Updated
- **Removed**: `sqflite`, `sqflite_common_ffi`
- **Added**: `hive`, `hive_flutter`, `hive_generator`, `path_provider`

#### New Files Created
- `lib/services/hive_offline_database.dart` - New Hive-based database service
- `lib/services/database_migration.dart` - Migration helper from SQLite to Hive

#### Updated Files
- `lib/models/user.dart` - Added Hive annotations
- `lib/models/assignment.dart` - Added Hive annotations
- `lib/services/offline_storage.dart` - Updated to use Hive for mobile
- `lib/main.dart` - Added database initialization and migration
- `pubspec.yaml` - Updated dependencies

### Benefits of Hive over SQLite

1. **Better Performance** - Faster read/write operations
2. **Cross-platform** - Works seamlessly on mobile, web, and desktop
3. **No Native Dependencies** - Pure Dart implementation
4. **Type-safe** - Better integration with Dart's type system
5. **Simpler API** - Easier to use than SQLite
6. **Better for Flutter** - Designed specifically for Flutter/Dart

### How to Use

#### 1. Install Dependencies
```bash
flutter pub get
```

#### 2. Generate Hive Adapters
```bash
flutter packages pub run build_runner build
```

#### 3. Database Initialization
The database is automatically initialized in `main.dart` with migration support:

```dart
// Automatic migration from SQLite to Hive
await _initializeDatabase();
```

#### 4. Using the Database

##### Save User
```dart
final user = User(id: 1, name: 'John Doe', role: 'inspector');
await HiveOfflineDatabase.saveUser(user);
```

##### Get Current User
```dart
final user = HiveOfflineDatabase.getCurrentUser();
```

##### Save Assignments
```dart
final assignments = [assignment1, assignment2, assignment3];
await HiveOfflineDatabase.saveAssignments(assignments);
```

##### Get Assignments
```dart
// Get all assignments
final allAssignments = HiveOfflineDatabase.getAssignments();

// Get assignments by status
final pendingAssignments = HiveOfflineDatabase.getAssignments(status: 'assigned');
```

##### Get Statistics
```dart
final stats = HiveOfflineDatabase.getAssignmentStatistics();
print('Total assignments: ${stats.totalAssignments}');
```

### Migration Process

The app automatically handles migration from SQLite to Hive:

1. **Check for existing SQLite data** - If found, migration is needed
2. **Migrate data** - Users, assignments, and sync status are migrated
3. **Initialize Hive** - New database is ready to use
4. **Optional cleanup** - Old SQLite database can be removed

### Database Structure

#### Hive Boxes
- `users` - Stores current user data
- `assignments` - Stores assignment data (keyed by assignment_id)
- `sync_status` - Stores sync status information

#### Data Models
All models now have Hive annotations:
- `@HiveType(typeId: 0)` for User
- `@HiveType(typeId: 1)` for Assignment
- `@HiveType(typeId: 2)` for AssignmentStatistics

### Troubleshooting

#### Common Issues

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

#### Debug Information

The app provides debug information about the database:
```dart
final info = HiveOfflineDatabase.getDatabaseInfo();
print('Database info: $info');
```

### Migration Checklist

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

### Next Steps

1. Run the build runner to generate Hive adapters
2. Test the app to ensure migration works correctly
3. Verify all offline functionality works as expected
4. Consider removing the old SQLite database files after successful migration

### Support

If you encounter any issues with the migration:
1. Check the console logs for error messages
2. Verify all dependencies are properly installed
3. Ensure build runner has generated the necessary files
4. Test with a fresh app installation to verify the new database works

---

## API Endpoint Requirements

### New Endpoint Needed

To support user-specific data syncing, you need to create a new API endpoint on your server:

#### Endpoint: `/mobile/get_user_assignments.php`

**Method:** GET  
**Parameters:** `inspector_role_id` (query parameter)

**Example URL:**
```
GET /mobile/get_user_assignments.php?inspector_role_id=123
```

### Expected Response Format

```json
{
  "success": true,
  "message": "Assignments retrieved successfully",
  "data": {
    "assignments": [
      {
        "assignment_id": 1,
        "status": "assigned",
        "inspection_date": "2024-01-15",
        "completion_date": null,
        "assigned_at": "2024-01-10T10:00:00Z",
        "assignment_notes": "Initial inspection required",
        "business_assignment_id": 101,
        "business_id": "BUS001",
        "business_name": "Sample Business",
        "business_address": "123 Main St",
        "business_notes": "Regular inspection",
        "department_name": "Building Department",
        "department_description": "Building inspections",
        "assigned_by_name": "Admin User",
        "assigned_by_admin": "admin@example.com"
      }
    ]
  }
}
```

### Error Response Format

```json
{
  "success": false,
  "message": "No assignments found for this inspector",
  "data": null
}
```

### Implementation Notes

1. **Authentication:** The endpoint should verify that the user is logged in and has permission to access their assignments.

2. **Filtering:** Only return assignments where the `inspector_role_id` matches the provided parameter.

3. **Security:** Ensure that users can only access their own assignments, not other users' data.

4. **Database Query:** The query should filter assignments based on the inspector's role ID.

### Example PHP Implementation

```php
<?php
header('Content-Type: application/json');
session_start();

// Check if user is logged in
if (!isset($_SESSION['user_id'])) {
    echo json_encode([
        'success' => false,
        'message' => 'Not logged in',
        'data' => null
    ]);
    exit;
}

$inspector_role_id = $_GET['inspector_role_id'] ?? null;

if (!$inspector_role_id) {
    echo json_encode([
        'success' => false,
        'message' => 'Inspector role ID is required',
        'data' => null
    ]);
    exit;
}

// Verify user has permission to access this inspector's data
$user_id = $_SESSION['user_id'];
$user_role = $_SESSION['user_role'];

// If not admin, ensure user can only access their own data
if ($user_role !== 'admin') {
    $user_inspector_role = $_SESSION['inspector_role_id'];
    if ($user_inspector_role != $inspector_role_id) {
        echo json_encode([
            'success' => false,
            'message' => 'Access denied',
            'data' => null
        ]);
        exit;
    }
}

// Database query to get assignments for the inspector
$sql = "SELECT * FROM assignments WHERE inspector_role_id = ?";
$stmt = $pdo->prepare($sql);
$stmt->execute([$inspector_role_id]);
$assignments = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo json_encode([
    'success' => true,
    'message' => 'Assignments retrieved successfully',
    'data' => [
        'assignments' => $assignments
    ]
]);
?>
```

### Offline Login Support

The mobile app now supports offline login by storing user credentials securely when they sync their data. This allows users to:

1. **Sync their data** → Stores assignments + credentials
2. **Login offline** → Uses stored credentials for authentication
3. **Access assignments** → View and work with synced data offline

### Credential Storage

When a user syncs their data, the following information is stored securely:

```json
{
  "username": "john_doe",
  "user_id": 123,
  "inspector_role_id": "INSP001",
  "role": "inspector",
  "status": "active",
  "synced_at": "2024-01-15T10:30:00Z"
}
```

### Security Notes

- **No passwords stored:** Only user identification data is stored
- **Encrypted storage:** Credentials are stored securely in device storage
- **Automatic cleanup:** Credentials are cleared when user logs out or clears data

### Benefits of This Approach

1. **Security:** Users can only access their own data
2. **Performance:** Only relevant data is downloaded
3. **Scalability:** Reduces server load and bandwidth usage
4. **User Experience:** Faster sync times for individual users
5. **Privacy:** Ensures data privacy and compliance
6. **Offline Access:** Users can login and work offline after syncing

### Migration Path

1. **Phase 1:** Create the new endpoint
2. **Phase 2:** Update the mobile app to use the new endpoint
3. **Phase 3:** Test with different user roles
4. **Phase 4:** Remove or deprecate the old admin-only endpoints if no longer needed

---

## Asset Management & Icon Setup

### How to Change Flutter Logo to Ormoc City Official Seal

#### Step 1: Choose Your Logo
You have these Ormoc City logos available:
- `assets/ormoc_seal.png` - **CITY OF ORMOC OFFICIAL SEAL** ✅ **READY TO USE**
- `assets/obo_logo.png` (2.1MB) - Alternative OBO logo
- `C:\xampp\htdocs\OBO-LGU\images\logo.png` (668KB) - Original logo
- `C:\xampp\htdocs\OBO-LGU\images\Obo1.png` (268KB) - Alternative 1
- `C:\xampp\htdocs\OBO-LGU\images\Obo2.png` (261KB) - Alternative 2

#### Step 2: Generate All Required Icon Sizes

##### Option A: Use Online Icon Generator (Easiest)
1. Go to: https://appicon.co/ or https://icon.kitchen/
2. Upload your `assets/ormoc_seal.png` (City of Ormoc Official Seal)
3. Download the generated icon pack
4. Extract and replace the files in the directories below

##### Option B: Use Image Editing Software
Resize your logo to these exact sizes:

**Android Icons:**
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` → 48x48px
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` → 72x72px
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` → 96x96px
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` → 144x144px
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` → 192x192px

**iOS Icons:**
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png` → 20x20px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png` → 40x40px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png` → 60x60px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png` → 29x29px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png` → 58x58px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png` → 87x87px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png` → 40x40px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png` → 80x80px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png` → 120x120px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png` → 120x120px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png` → 180x180px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png` → 76x76px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png` → 152x152px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png` → 167x167px
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` → 1024x1024px

**Web Icons:**
- `web/icons/Icon-192.png` → 192x192px
- `web/icons/Icon-512.png` → 512x512px
- `web/icons/Icon-maskable-192.png` → 192x192px (with padding)
- `web/icons/Icon-maskable-512.png` → 512x512px (with padding)
- `web/favicon.png` → 32x32px or 64x64px

#### Step 3: Quick Test (Web Only)
For immediate testing in Chrome/Edge, just replace:
- `web/favicon.png` (browser tab icon)
- `web/icons/Icon-192.png` (web app icon)

#### Step 4: Update App Name (Optional)
Edit these files to change "OBO Mobile" to your preferred name:
- `android/app/src/main/AndroidManifest.xml` → `android:label="Ormoc OBO Inspector"`
- `ios/Runner/Info.plist` → `CFBundleDisplayName`
- `web/manifest.json` → `name` and `short_name`

#### Step 5: Test Your Changes
```bash
# Test in web browser
flutter run -d chrome

# Test Android APK
flutter build apk
```

### Quick Start (5 minutes)
1. Go to https://appicon.co/
2. Upload `assets/ormoc_seal.png` (City of Ormoc Official Seal)
3. Download the generated pack
4. Replace files in the directories above
5. Run `flutter run -d chrome` to test

### Result
Your app will show the Ormoc City Official Seal instead of Flutter logo in:
- ✅ Browser tab (favicon)
- ✅ Web app icon
- ✅ Android app icon (APK)
- ✅ iOS app icon (if building for iOS)
- ✅ App launcher on devices

### Asset Helper Features
- ✅ **Automatic fallback** to icons if images fail
- ✅ **Platform detection** (web vs mobile)
- ✅ **Error handling** with graceful degradation
- ✅ **Consistent loading** across platforms

### File Structure
```
OBO-MOBILE/
├── assets/
│   ├── ormoc_seal.png     ← Ormoc City Official Seal
│   ├── obo_logo.png       ← OBO Logo
│   └── logo.png           ← Alternative logo
├── lib/
│   ├── utils/
│   │   └── asset_helper.dart  ← Asset loading utility
│   └── main.dart             ← Uses AssetHelper.loadOrmocSeal()
└── pubspec.yaml              ← Assets configuration
```

### Asset Helper Usage
```dart
// Load Ormoc seal with fallback
AssetHelper.loadOrmocSeal(width: 60, height: 60)

// Load OBO logo with fallback  
AssetHelper.loadOboLogo(width: 60, height: 60)

// Load any asset with fallback
AssetHelper.loadImage(assetName: 'my_image.png')
```

---

## Testing Guide

### Step-by-Step Testing Guide

#### 1. Test in Web Browser First
```bash
flutter run -d chrome
```
- ✅ Check if Ormoc City seal appears in login screen
- ✅ If it shows fallback icon, assets are not loading properly

#### 2. Build APK with Proper Asset Handling
```bash
# Use the build script
.\build_apk.bat

# Or manually:
flutter clean
flutter pub get
flutter build apk --release
```

#### 3. Install APK on Android Device
1. **Copy APK** to your Android device
2. **Enable Unknown Sources** in Android settings
3. **Install APK** on device
4. **Test the app** - check if Ormoc City seal appears

#### 4. Troubleshooting Asset Issues

##### If Images Don't Show in APK:
1. **Check asset paths** in `pubspec.yaml`
2. **Verify files exist** in `assets/` folder
3. **Clean and rebuild** the project
4. **Check APK contents** (optional)

#### 5. Expected Results

##### Web Browser (Chrome/Edge):
- Ormoc City seal should display properly
- Fallback icon if image fails to load

##### Android APK:
- Ormoc City seal should display properly
- Fallback icon if image fails to load
- No crashes or errors

### Success Criteria
- ✅ Images display in web browser
- ✅ Images display in APK on Android device
- ✅ Fallback icons work if images fail
- ✅ No crashes or errors
- ✅ Consistent behavior across platforms

---

## License

This project is part of the OBO-LGU system for Ormoc City.

---

**Last Updated:** 2024