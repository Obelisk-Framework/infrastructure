@echo off
setlocal enabledelayedexpansion

rem Downloads a FXServer windows build into .\fxserver (bind-mounted into the
rem fxserver container by docker-compose.yml).
rem
rem Usage: scripts\update-fivem-server.bat [recommended|latest|optional|critical]

set "CHANNEL=%~1"
if "%CHANNEL%"=="" set "CHANNEL=recommended"

set "SCRIPT_DIR=%~dp0"
set "TARGET_DIR=%SCRIPT_DIR%..\fxserver"
set "API_URL=https://changelogs-live.fivem.net/api/changelog/versions/win32/server"

echo Fetching '%CHANNEL%' FXServer build info...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "try {" ^
  "  $resp = Invoke-RestMethod -Uri '%API_URL%';" ^
  "  $url = $resp.('%CHANNEL%_download');" ^
  "  $build = $resp.('%CHANNEL%');" ^
  "  if (-not $url) { throw \"Could not resolve download URL for channel '%CHANNEL%'\" }" ^
  "  Write-Host \"Latest %CHANNEL% build: $build\";" ^
  "  Write-Host \"Downloading: $url\";" ^
  "  New-Item -ItemType Directory -Force -Path '%TARGET_DIR%' | Out-Null;" ^
  "  $zip = Join-Path $env:TEMP 'fxserver-update.zip';" ^
  "  Invoke-WebRequest -Uri $url -OutFile $zip;" ^
  "  Write-Host 'Extracting...';" ^
  "  Expand-Archive -Path $zip -DestinationPath '%TARGET_DIR%' -Force;" ^
  "  Remove-Item $zip;" ^
  "  Set-Content -Path (Join-Path '%TARGET_DIR%' '.build-version') -Value $build -NoNewline;" ^
  "  Write-Host \"FXServer updated to build $build (%CHANNEL%).\";" ^
  "} catch {" ^
  "  Write-Error $_;" ^
  "  exit 1;" ^
  "}"

if errorlevel 1 (
    echo Update failed.
    exit /b 1
)

echo Done.
endlocal
