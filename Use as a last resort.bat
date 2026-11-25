@echo off
setlocal EnableDelayedExpansion

set "WIN_TITLE=Command Window for recovering your PC and opening higher privilege windows."
title %WIN_TITLE%

:: 1. Ensure Administrator privileges first
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [PRIVILEGE] Requesting Administrator elevation...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: 2. Direct path detection without repeated 'where.exe' calls
set "SCRIPT_DIR=%~dp0"
set "GSUDO_EXE="
set "PSEXEC_EXE="

if exist "%SCRIPT_DIR%gsudo.exe" set "GSUDO_EXE=%SCRIPT_DIR%gsudo.exe"
if not defined GSUDO_EXE if exist "%ProgramFiles%\gsudo\Current\gsudo.exe" set "GSUDO_EXE=%ProgramFiles%\gsudo\Current\gsudo.exe"

if exist "%SCRIPT_DIR%PsExec64.exe" (
    set "PSEXEC_EXE=%SCRIPT_DIR%PsExec64.exe"
) else if exist "%SCRIPT_DIR%PsExec.exe" (
    set "PSEXEC_EXE=%SCRIPT_DIR%PsExec.exe"
) else if exist "%ProgramFiles%\Sysinternals\PsExec64.exe" (
    set "PSEXEC_EXE=%ProgramFiles%\Sysinternals\PsExec64.exe"
) else if exist "%ProgramFiles%\Sysinternals\PsExec.exe" (
    set "PSEXEC_EXE=%ProgramFiles%\Sysinternals\PsExec.exe"
)

:: 3. Attempt higher privilege escalation FIRST (TrustedInstaller via gsudo, then SYSTEM via PsExec)
set "ELEVATED_LAUNCHED=0"
if defined GSUDO_EXE (
    echo [PRIVILEGE] Attempting TrustedInstaller shell via gsudo --ti...
    "%GSUDO_EXE%" --ti cmd /c "title %WIN_TITLE% & echo [TI-SHELL] Active"
    if !errorlevel! equ 0 set "ELEVATED_LAUNCHED=1"
)

if "%ELEVATED_LAUNCHED%"=="0" if defined PSEXEC_EXE (
    echo [PRIVILEGE] Attempting SYSTEM shell via PsExec...
    "%PSEXEC_EXE%" -accepteula -s -i cmd.exe /c "title %WIN_TITLE% & echo [SYSTEM-SHELL] Active"
    if !errorlevel! equ 0 set "ELEVATED_LAUNCHED=1"
)

:: 4. Disable non-Microsoft scheduled tasks (keeping Windows/Microsoft tasks intact)
echo [LOCKDOWN] Disabling non-Microsoft scheduled tasks...
powershell -NoProfile -Command ^
  "$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notlike '\Microsoft*' }; " ^
  "foreach ($t in $tasks) { " ^
  "  try { Disable-ScheduledTask -InputObject $t -ErrorAction SilentlyContinue | Out-Null } catch {} " ^
  "}"

:: 5. Terminate unapproved processes while strictly protecting your 36 core Windows processes & active recovery tools
echo [LOCKDOWN] Cleaning non-essential processes (Core Windows & Security processes protected)...
powershell -NoProfile -Command ^
  "$protected = @(" ^
  "  'System', 'ntoskrnl', 'System Idle Process', 'Idle', 'smss', 'csrss', 'wininit', 'services', " ^
  "  'lsass', 'lsaiso', 'svchost', 'fontdrvhost', 'dwm', 'winlogon', 'explorer', 'sihost', " ^
  "  'taskhostw', 'ctfmon', 'StartMenuExperienceHost', 'ShellExperienceHost', 'SearchHost', 'SearchApp', " ^
  "  'RuntimeBroker', 'ApplicationFrameHost', 'TextInputHost', 'MsMpEng', 'SecurityHealthService', " ^
  "  'SecurityHealthSystray', 'NisSrv', 'audiodg', 'spoolsv', 'WmiPrvSE', 'dllhost', 'conhost', " ^
  "  'dasHost', 'SearchIndexer', 'Registry', 'Memory Compression', " ^
  "  'cmd', 'powershell', 'pwsh', 'gsudo', 'PsExec', 'PsExec64', 'sfc', 'DISM', 'mrt', 'MBSetup'" ^
  "); " ^
  "$selfPid = $PID; " ^
  "$procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { " ^
  "  $_.Id -ne $selfPid -and ($_.ProcessName -notin $protected) " ^
  "}; " ^
  "foreach ($p in $procs) { " ^
  "  try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Write-Host ('[TERMINATED] ' + $p.ProcessName + ' (PID: ' + $p.Id + ')') } catch {} " ^
  "}"

:: 6. Run SFC /scannow; if issues remain, run DISM RestoreHealth then retry SFC
echo [REPAIR] Running SFC /scannow...
sfc /scannow
if errorlevel 1 (
    echo [REPAIR] SFC detected issues or was interrupted. Running DISM RestoreHealth...
    DISM /Online /Cleanup-Image /RestoreHealth
    echo [REPAIR] Re-running SFC /scannow after DISM...
    sfc /scannow
)

:: 7. Launch Microsoft Windows Malicious Software Removal Tool (MRT)
if exist "%SystemRoot%\System32\mrt.exe" (
    echo [SCANNER] Launching Microsoft Windows Malicious Software Removal Tool (mrt.exe)...
    start "" "%SystemRoot%\System32\mrt.exe"
) else (
    echo [WARNING] mrt.exe not found in System32.
)

:: 8. Launch local Malwarebytes installer if present, or download official installer
set "MB_EXE=%SCRIPT_DIR%MBSetup.exe"
if not exist "%MB_EXE%" set "MB_EXE=%USERPROFILE%\Downloads\MBSetup.exe"
if exist "%MB_EXE%" (
    echo [SCANNER] Launching Malwarebytes installer...
    start "" "%MB_EXE%"
) else (
    echo [SCANNER] Downloading Malwarebytes installer...
    powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'https://data-cdn.mbamupdates.com/web/mb4-setup-consumer/MBSetup.exe' -OutFile '$env:TEMP\MBSetup.exe' -UseBasicParsing; Start-Process '$env:TEMP\MBSetup.exe' } catch { Write-Host '[INFO] Manual download required: https://www.malwarebytes.com/mwb-download' }"
)

:: 9. Keep elevated recovery command prompt open for manual inspection if needed
echo.
echo ====================================================================
echo [DONE] Recovery sequence finished. Protected core processes untouched.
echo ====================================================================
cmd /k "title %WIN_TITLE%"
endlocal
