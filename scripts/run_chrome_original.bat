@echo off
title Jannati - Quick Test (No Data Persistence)
echo ========================================
echo   WARNING: Data will be LOST between runs
echo ========================================
echo.
echo This mode uses a TEMPORARY Chrome profile.
echo All your dhikr data will disappear when you
echo close Chrome or restart flutter run.
echo.
echo Use scripts\run_dev.bat for persistent data.
echo.
timeout /t 5 /nobreak >nul
flutter run -d chrome --web-port=8080
pause
