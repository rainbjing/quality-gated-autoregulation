@echo off
rem NSCA-FitMotion launcher for Windows. Double-click to run.
rem Starts a local-only web server on http://localhost:8765/ and opens your browser.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Windows.ps1"
if errorlevel 1 (
  echo.
  pause
)
