# 🧪 Testing Asset Loading in APK

## 📋 **Step-by-Step Testing Guide**

### **1. Test in Web Browser First**
```bash
flutter run -d chrome
```
- ✅ Check if Ormoc City seal appears in login screen
- ✅ If it shows fallback icon, assets are not loading properly

### **2. Build APK with Proper Asset Handling**
```bash
# Use the build script
.\build_apk.bat

# Or manually:
flutter clean
flutter pub get
flutter build apk --release
```

### **3. Install APK on Android Device**
1. **Copy APK** to your Android device
2. **Enable Unknown Sources** in Android settings
3. **Install APK** on device
4. **Test the app** - check if Ormoc City seal appears

### **4. Troubleshooting Asset Issues**

#### **If Images Don't Show in APK:**
1. **Check asset paths** in `pubspec.yaml`
2. **Verify files exist** in `assets/` folder
3. **Clean and rebuild** the project
4. **Check APK contents** (optional)

#### **Asset Helper Features:**
- ✅ **Automatic fallback** to icons if images fail
- ✅ **Platform detection** (web vs mobile)
- ✅ **Error handling** with graceful degradation
- ✅ **Consistent loading** across platforms

### **5. Expected Results**

#### **Web Browser (Chrome/Edge):**
- Ormoc City seal should display properly
- Fallback icon if image fails to load

#### **Android APK:**
- Ormoc City seal should display properly
- Fallback icon if image fails to load
- No crashes or errors

### **6. File Structure**
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

### **7. Asset Helper Usage**
```dart
// Load Ormoc seal with fallback
AssetHelper.loadOrmocSeal(width: 60, height: 60)

// Load OBO logo with fallback  
AssetHelper.loadOboLogo(width: 60, height: 60)

// Load any asset with fallback
AssetHelper.loadImage(assetName: 'my_image.png')
```

## 🎯 **Success Criteria**
- ✅ Images display in web browser
- ✅ Images display in APK on Android device
- ✅ Fallback icons work if images fail
- ✅ No crashes or errors
- ✅ Consistent behavior across platforms


