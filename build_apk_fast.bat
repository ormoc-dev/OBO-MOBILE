@echo off
echo 🚀 Building OBO Mobile APK (Fast Mode)
echo =====================================

echo.
echo 📦 Cleaning previous builds...
flutter clean

echo.
echo 📥 Getting dependencies...
flutter pub get

echo.
echo 🔧 Running code generation (if needed)...
flutter packages pub run build_runner build --delete-conflicting-outputs

echo.
echo 🏗️ Building APK in release mode (optimized)...
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info

echo.
echo ✅ Build completed! APK files are in: build/app/outputs/flutter-apk/
echo.
echo 📱 Generated APKs:
echo    - app-arm64-v8a-release.apk (64-bit ARM)
echo    - app-armeabi-v7a-release.apk (32-bit ARM)
echo    - app-x86_64-release.apk (64-bit x86)
echo.
echo 💡 Tip: Use app-arm64-v8a-release.apk for most modern Android devices
echo.
pause
