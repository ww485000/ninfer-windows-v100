@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo Starting Qwen3.8-27B NVFP4 official on http://127.0.0.1:7105 ...
powershell.exe -NoLogo -NoProfile -Command "$c = Get-NetTCPConnection -LocalPort 7105 -State Listen -ErrorAction SilentlyContinue; if ($c) { Write-Host 'Port 7105 is already in use. Run stop-qwen38-server.bat first.' -ForegroundColor Yellow; exit 10 }"
if not "%ERRORLEVEL%"=="0" (
  pause
  exit /b %ERRORLEVEL%
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve-qwen38-v100.ps1" -Variant official -Port 7105

set "EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%EXIT_CODE%"=="0" echo Server exited with code %EXIT_CODE%.
pause
exit /b %EXIT_CODE%
