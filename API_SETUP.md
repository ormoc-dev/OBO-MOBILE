# Flutter App API Integration Setup

This guide will help you connect your Flutter app to your PHP API running on XAMPP.

## Prerequisites

1. XAMPP server running with your PHP API
2. Flutter development environment set up
3. Your PHP API accessible at `http://localhost/OBO-LGU/api/auth/login.php`

## Step 1: Install Dependencies

Run the following command in your Flutter project directory:

```bash
flutter pub get
```

## Step 2: Configure API URL

1. Open `lib/config/app_config.dart`
2. Update the `baseUrl` based on your testing environment:

### For Android Emulator:
```dart
static const String baseUrl = 'http://10.0.2.2/OBO-LGU/api';
```

### For Physical Device:
1. Find your computer's IP address:
   - Windows: Run `ipconfig` in Command Prompt
   - Mac/Linux: Run `ifconfig` in Terminal
2. Update the URL:
```dart
static const String baseUrl = 'http://YOUR_IP_ADDRESS/OBO-LGU/api';
```

### For Web Development:
```dart
static const String baseUrl = 'http://localhost/OBO-LGU/api';
```

## Step 3: Test API Connection

1. Make sure XAMPP is running
2. Test your API endpoint in a browser: `http://localhost/OBO-LGU/api/auth/login.php`
3. You should see a JSON response indicating the method is not allowed (since it's a POST endpoint)

## Step 4: Run the Flutter App

```bash
flutter run
```

## Step 5: Test Login

1. Use the login credentials from your database
2. The app should successfully authenticate and redirect to the dashboard

## Troubleshooting

### Common Issues:

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

### Testing API Endpoints:

You can test your API using tools like Postman or curl:

```bash
curl -X POST http://localhost/OBO-LGU/api/auth/login.php \
  -H "Content-Type: application/json" \
  -d '{"username":"your_username","password":"your_password","remember":false}'
```

## File Structure

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

## Features Implemented

- ✅ User authentication with PHP API
- ✅ Session management with local storage
- ✅ Remember me functionality
- ✅ Automatic login check on app start
- ✅ Dashboard with user information
- ✅ Logout functionality
- ✅ Error handling and user feedback
- ✅ Loading states and UI feedback

## Next Steps

1. Add more API endpoints as needed
2. Implement additional features like:
   - User profile management
   - Application forms
   - Inspection scheduling
   - Report generation
3. Add push notifications
4. Implement offline functionality
5. Add biometric authentication

## Security Notes

- The current implementation stores user data locally
- Consider implementing token-based authentication
- Add proper error handling for production
- Implement proper session timeout
- Consider adding certificate pinning for production
