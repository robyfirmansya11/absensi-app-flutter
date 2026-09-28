@echo off
setlocal
cd /d "%~dp0"

rem Production is explicit; normal Flutter runs continue to use development.
call flutter pub get
if errorlevel 1 exit /b 1

call flutter build apk --release --dart-define=APP_ENV=production --obfuscate --split-debug-info=build/debug-info
if errorlevel 1 exit /b 1

if not exist "dist" mkdir "dist"
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "dist\InSys-production.apk"
if errorlevel 1 exit /b 1

echo Production APK: %CD%\dist\InSys-production.apk
echo Keep build\debug-info securely with this release for crash diagnostics.
endlocal
