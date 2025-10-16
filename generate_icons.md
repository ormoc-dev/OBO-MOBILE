# 🏛️ How to Change Flutter Logo to Ormoc City Official Seal

## 📋 **Step-by-Step Instructions**

### **1. Choose Your Logo**
You have these Ormoc City logos available:
- `assets/ormoc_seal.png` - **CITY OF ORMOC OFFICIAL SEAL** ✅ **READY TO USE**
- `assets/obo_logo.png` (2.1MB) - Alternative OBO logo
- `C:\xampp\htdocs\OBO-LGU\images\logo.png` (668KB) - Original logo
- `C:\xampp\htdocs\OBO-LGU\images\Obo1.png` (268KB) - Alternative 1
- `C:\xampp\htdocs\OBO-LGU\images\Obo2.png` (261KB) - Alternative 2

### **2. Generate All Required Icon Sizes**

#### **Option A: Use Online Icon Generator (Easiest)**
1. Go to: https://appicon.co/ or https://icon.kitchen/
2. Upload your `assets/ormoc_seal.png` (City of Ormoc Official Seal)
3. Download the generated icon pack
4. Extract and replace the files in the directories below

#### **Option B: Use Image Editing Software**
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

### **3. Quick Test (Web Only)**
For immediate testing in Chrome/Edge, just replace:
- `web/favicon.png` (browser tab icon)
- `web/icons/Icon-192.png` (web app icon)

### **4. Update App Name (Optional)**
Edit these files to change "OBO Mobile" to your preferred name:
- `android/app/src/main/AndroidManifest.xml` → `android:label="Ormoc OBO Inspector"`
- `ios/Runner/Info.plist` → `CFBundleDisplayName`
- `web/manifest.json` → `name` and `short_name`

### **5. Test Your Changes**
```bash
# Test in web browser
flutter run -d chrome

# Test Android APK
flutter build apk
```

## 🎯 **Quick Start (5 minutes)**
1. Go to https://appicon.co/
2. Upload `assets/ormoc_seal.png` (City of Ormoc Official Seal)
3. Download the generated pack
4. Replace files in the directories above
5. Run `flutter run -d chrome` to test

## 📱 **Result**
Your app will show the Ormoc City Official Seal instead of Flutter logo in:
- ✅ Browser tab (favicon)
- ✅ Web app icon
- ✅ Android app icon (APK)
- ✅ iOS app icon (if building for iOS)
- ✅ App launcher on devices
