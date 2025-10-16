@echo off
echo 🚀 Building OBO Mobile APK with proper asset handling...
echo.

REM Clean the project first
echo 📦 Cleaning project...
flutter clean
if %errorlevel% neq 0 (
    echo ❌ Clean failed!
    pause
    exit /b 1
)

REM Get dependencies
echo 📥 Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ❌ Pub get failed!
    pause
    exit /b 1
)

REM Build APK
echo 🔨 Building APK...
flutter build apk --release
if %errorlevel% neq 0 (
    echo ❌ APK build failed!
    pause
    exit /b 1
)

echo.
echo ✅ APK built successfully!
echo 📱 APK location: build\app\outputs\flutter-apk\app-release.apk
echo.
echo 📋 Installation instructions:
echo 1. Copy the APK to your Android device
echo 2. Enable "Install from unknown sources" in Android settings
echo 3. Install the APK
echo 4. Test the Ormoc City seal logo
echo.
pause
