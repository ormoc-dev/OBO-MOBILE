#!/bin/bash
echo "⚡ Building OBO Mobile APK (Ultra Fast Mode)"
echo "==========================================="

echo ""
echo "🏗️ Building APK in release mode (no obfuscation for speed)..."
flutter build apk --release --split-per-abi

echo ""
echo "✅ Build completed! APK files are in: build/app/outputs/flutter-apk/"
echo ""
echo "📱 Generated APKs:"
echo "   - app-arm64-v8a-release.apk (64-bit ARM) - Use this one!"
echo "   - app-armeabi-v7a-release.apk (32-bit ARM)"
echo "   - app-x86_64-release.apk (64-bit x86)"
echo ""
