@echo off
echo 🚀 Running Jannati on Chrome with fixed port 8080...
echo ⚠️ Note: Uses TEMPORARY Chrome profile. Data lost between sessions.
echo ✅ Use scripts\run_dev.bat for persistent data.
echo.
flutter run -d chrome --web-port=8080
pause
