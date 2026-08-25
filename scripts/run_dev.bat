@echo off
title Jannati - Dev Mode (Persistent Data)
echo ========================================
echo   Jannati Dev Mode - Persistent Data
echo ========================================
echo.
set CHROME_PROFILE=%LOCALAPPDATA%\chrome-jannati-dev

REM إنشاء profile دائم لـ Chrome (مرة واحدة فقط)
if not exist "%CHROME_PROFILE%" mkdir "%CHROME_PROFILE%"
echo ^- Chrome profile: %CHROME_PROFILE%

REM فتح Chrome مع profile دائم
echo ^- Opening Chrome with persistent profile...
start "" chrome --user-data-dir="%CHROME_PROFILE%" http://localhost:8080

REM تشغيل Flutter web server
echo.
echo Starting Flutter on port 8080...
echo Close this window or press Ctrl+C to stop.
echo.
flutter run -d web-server --web-port=8080

pause
