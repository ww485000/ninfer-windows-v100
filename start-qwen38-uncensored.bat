@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo Starting Qwen3.8-27B NVFP4 uncensored on http://127.0.0.1:7105 ...
powershell.exe -NoLogo -NoProfile -Command "$c = Get-NetTCPConnection -LocalPort 7105 -State Listen -ErrorAction SilentlyContinue; if ($c) { exit 10 }; exit 0"
set "PREFLIGHT_EXIT=%ERRORLEVEL%"
if "%PREFLIGHT_EXIT%"=="10" (
  echo Port 7105 is already in use. Run stop-qwen38-server.bat first.
  pause
  exit /b 10
)
if not "%PREFLIGHT_EXIT%"=="0" (
  echo Unable to check port 7105. PowerShell exited with code %PREFLIGHT_EXIT%.
  pause
  exit /b %PREFLIGHT_EXIT%
)
if exist "%~dp0.local\qwen38-stop-requested" del /q "%~dp0.local\qwen38-stop-requested"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve-qwen38-v100.ps1" -Variant uncensored -Port 7105

set "EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%EXIT_CODE%"=="0" echo Server exited with code %EXIT_CODE%.
pause
exit /b %EXIT_CODE%
