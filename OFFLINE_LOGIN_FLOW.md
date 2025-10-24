# Offline Login Flow

## How Offline Login Works

### 1. Initial Setup (Online)
```
User Login → Sync Data → Store Credentials + Assignments
```

### 2. Offline Login Process
```
App Launch → Check Internet → No Internet → Use Offline Login
```

### 3. Detailed Flow

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

## Security Features

### What's Stored
- ✅ Username
- ✅ User ID
- ✅ Inspector Role ID
- ✅ User Role
- ✅ User Status
- ✅ Sync Timestamp

### What's NOT Stored
- ❌ Password (never stored)
- ❌ Other users' data
- ❌ Sensitive server tokens

### Security Measures
- Credentials stored in encrypted device storage
- Only accessible to the app
- Automatically cleared on logout
- User can manually clear all data

## User Experience

### Online Flow
```
Login → Dashboard → Sync My Data → Ready for Offline
```

### Offline Flow
```
App Launch → Login Screen → Enter Username → Access Assignments
```

### Benefits
- 🔒 **Secure**: No passwords stored
- ⚡ **Fast**: Instant offline login
- 📱 **Convenient**: Works without internet
- 🔄 **Reliable**: Data persists between sessions

## Error Handling

### Common Scenarios
1. **No Offline Data**: User must sync first when online
2. **Wrong Username**: Only synced user can login offline
3. **Expired Data**: User should re-sync when online
4. **Corrupted Data**: User can clear and re-sync

### User Messages
- "No offline data available. Please connect to internet and sync first."
- "Username not found in offline data. Please sync your data first."
- "Offline login successful. You can now access your assignments."

## Implementation Notes

### Files Modified
- `offline_sync_service.dart` - Added credential storage
- `auth_service.dart` - Enhanced offline authentication
- `dashboard_screen.dart` - Updated sync functionality
- `debug_screen.dart` - Added offline status display

### API Requirements
- New endpoint: `/mobile/get_user_assignments.php`
- Returns user-specific assignments
- Requires authentication
- Filters by inspector_role_id

### Database Changes
- Uses Hive for offline storage
- SharedPreferences for credentials
- Automatic cleanup on logout


