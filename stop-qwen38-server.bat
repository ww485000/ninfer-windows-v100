@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo Stopping NInfer server on http://127.0.0.1:7105 ...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$connections = Get-NetTCPConnection -LocalPort 7105 -State Listen -ErrorAction SilentlyContinue; " ^
  "if (-not $connections) { Write-Host 'No server is listening on port 7105.'; exit 0 }; " ^
  "$processIds = @($connections | Select-Object -ExpandProperty OwningProcess -Unique); " ^
  "$marker = Join-Path (Get-Location) '.local\qwen38-stop-requested'; " ^
  "New-Item -ItemType Directory -Force -Path (Split-Path $marker) | Out-Null; " ^
  "foreach ($processId in $processIds) { " ^
  "  $process = Get-Process -Id $processId -ErrorAction Stop; " ^
  "  if ($process.ProcessName -ne 'ninfer-serve') { throw ('Port 7105 belongs to ' + $process.ProcessName + '; refusing to stop it.') }; " ^
  "  Set-Content -LiteralPath $marker -Value $processId; " ^
  "  Stop-Process -Id $processId -Force -ErrorAction Stop; " ^
  "  Wait-Process -Id $processId -Timeout 15 -ErrorAction SilentlyContinue; " ^
  "  Write-Host ('Stopped ninfer-serve process ' + $processId + '.') " ^
  "}"

set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
  echo Failed to stop the server.
  pause
)
exit /b %EXIT_CODE%
