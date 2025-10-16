@echo off
echo 🎨 Updating OBO Mobile Web Icons...
echo.

REM Check if source logo exists
if not exist "assets\ormoc_seal.png" (
    echo ❌ Error: assets\ormoc_seal.png not found!
    echo Please make sure you have copied the Ormoc City seal to assets\ormoc_seal.png
    pause
    exit /b 1
)

echo ✅ Found Ormoc City seal: assets\ormoc_seal.png
echo.

REM Create backup of original icons
echo 📦 Creating backup of original icons...
if not exist "web\icons\backup" mkdir "web\icons\backup"
copy "web\icons\Icon-192.png" "web\icons\backup\Icon-192.png.bak" >nul 2>&1
copy "web\icons\Icon-512.png" "web\icons\backup\Icon-512.png.bak" >nul 2>&1
copy "web\icons\Icon-maskable-192.png" "web\icons\backup\Icon-maskable-192.png.bak" >nul 2>&1
copy "web\icons\Icon-maskable-512.png" "web\icons\backup\Icon-maskable-512.png.bak" >nul 2>&1
copy "web\favicon.png" "web\icons\backup\favicon.png.bak" >nul 2>&1

echo ✅ Backup created in web\icons\backup\
echo.

echo 🔄 Replacing web icons with OBO logo...
echo.
echo ⚠️  NOTE: This script copies the same image to all sizes.
echo    For best results, use an online icon generator to create
echo    properly sized icons from assets\ormoc_seal.png
echo.

REM Copy the Ormoc City seal to all web icon locations
copy "assets\ormoc_seal.png" "web\icons\Icon-192.png" >nul
copy "assets\ormoc_seal.png" "web\icons\Icon-512.png" >nul
copy "assets\ormoc_seal.png" "web\icons\Icon-maskable-192.png" >nul
copy "assets\ormoc_seal.png" "web\icons\Icon-maskable-512.png" >nul
copy "assets\ormoc_seal.png" "web\favicon.png" >nul

echo ✅ Web icons updated!
echo.
echo 🚀 To test your changes:
echo    1. Run: flutter run -d chrome
echo    2. Check the browser tab icon
echo    3. Check the web app icon
echo.
echo 📋 For Android/iOS icons, use the guide in generate_icons.md
echo.
pause
