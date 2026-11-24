@echo off
setlocal EnableDelayedExpansion

:: Set the requested English window title
set "WIN_TITLE=Command Window for recovering your PC and opening higher privilege windows."
title %WIN_TITLE%

:: Check Administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: 1. Temporarily pause Windows Defender Real-Time Monitoring (may be blocked if Tamper Protection is ON)
echo [DEFENDER] Attempting to pause Real-Time Monitoring...
powershell -NoProfile -Command "try { Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop; Write-Host 'Real-Time Monitoring paused.' } catch { Write-Host 'Could not change Defender setting (Tamper Protection or policy may block it).' }"

:: 2. Refresh script directory and common tool paths first
set "SCRIPT_DIR=%~dp0"
if exist "%SCRIPT_DIR%" (
    set "PATH=%SCRIPT_DIR%;%PATH%"
)
if exist "%ProgramFiles%\gsudo\Current\gsudo.exe" (
    set "PATH=%ProgramFiles%\gsudo\Current;%PATH%"
)
if exist "%ProgramFiles%\Sysinternals\PsExec64.exe" (
    set "PATH=%ProgramFiles%\Sysinternals;%PATH%"
)
if exist "%ProgramFiles%\Sysinternals\PsExec.exe" (
    set "PATH=%ProgramFiles%\Sysinternals;%PATH%"
)

:: 3. Immediate Lockdown: Disable non-Microsoft scheduled tasks & terminate non-essential processes
echo [LOCKDOWN] Disabling non-Microsoft scheduled tasks...
powershell -NoProfile -Command ^
  "$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notlike '\Microsoft*' }; " ^
  "foreach ($t in $tasks) { " ^
  "  try { Disable-ScheduledTask -InputObject $t -ErrorAction SilentlyContinue | Out-Null } catch {} " ^
  "}"

echo [LOCKDOWN] Terminating non-essential running processes...
powershell -NoProfile -Command ^
  "$protected = @('System','Idle','Registry','smss','csrss','wininit','services','lsass','winlogon','svchost','dwm','fontdrvhost','conhost','cmd','powershell','pwsh','explorer','sihost','taskhostw','RuntimeBroker','SecurityHealthService','MsMpEng'); " ^
  "$selfPid = $PID; " ^
  "$procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { " ^
  "  $_.Id -ne $selfPid -and " ^
  "  ($_.ProcessName -notin $protected) -and " ^
  "  ($_.Path -notlike ($env:SystemRoot + '\System32\*')) -and " ^
  "  ($_.Path -notlike ($env:SystemRoot + '\SysWOW64\*')) " ^
  "}; " ^
  "foreach ($p in $procs) { " ^
  "  try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {} " ^
  "}"

:: 4. Check if winget is available and active
set "WINGET_READY=0"
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget --info >nul 2>&1
    if %errorlevel% equ 0 (
        set "WINGET_READY=1"
    )
)

:: 5. Check or install gsudo
set "GSUDO_PATH="
where gsudo >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%I in ('where gsudo 2^>nul') do (
        if not defined GSUDO_PATH set "GSUDO_PATH=%%I"
    )
) else (
    if "%WINGET_READY%"=="1" (
        echo gsudo not found. Installing via winget...
        winget install --id gerardog.gsudo -e --accept-source-agreements --accept-package-agreements
        if exist "%ProgramFiles%\gsudo\Current\gsudo.exe" (
            set "PATH=%ProgramFiles%\gsudo\Current;%PATH%"
            set "GSUDO_PATH=%ProgramFiles%\gsudo\Current\gsudo.exe"
        ) else (
            where gsudo >nul 2>&1
            if %errorlevel% equ 0 (
                for /f "delims=" %%I in ('where gsudo 2^>nul') do (
                    if not defined GSUDO_PATH set "GSUDO_PATH=%%I"
                )
            )
        )
    )
)

:: 6. Run SFC /scannow; if blocked or non-zero, run DISM RestoreHealth then retry SFC
echo [REPAIR] Running SFC /scannow...
sfc /scannow
set "SFC_RC=%errorlevel%"
if %SFC_RC% neq 0 (
    echo [WARNING] SFC returned code %SFC_RC%. Running DISM RestoreHealth...
    DISM /Online /Cleanup-Image /RestoreHealth
    echo [REPAIR] Re-running SFC /scannow after DISM...
    sfc /scannow
)

:: 7. Launch Microsoft Malicious Software Removal Tool (MRT)
echo [MRT] Launching Microsoft Windows Malicious Software Removal Tool (mrt.exe)...
if exist "%SystemRoot%\System32\mrt.exe" (
    start "" "%SystemRoot%\System32\mrt.exe"
) else (
    echo [WARNING] mrt.exe not found in System32.
)

:: 8. Check or launch Malwarebytes installer (local first, then download fallback)
set "MB_EXE=%SCRIPT_DIR%MBSetup.exe"
if not exist "%MB_EXE%" set "MB_EXE=%USERPROFILE%\Downloads\MBSetup.exe"
if exist "%MB_EXE%" (
    echo [SCANNER] Launching Malwarebytes installer...
    start "" "%MB_EXE%"
) else (
    echo [SCANNER] Downloading Malwarebytes installer...
    powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'https://data-cdn.mbamupdates.com/web/mb4-setup-consumer/MBSetup.exe' -OutFile '$env:TEMP\MBSetup.exe' -UseBasicParsing; Start-Process '$env:TEMP\MBSetup.exe' } catch { Write-Host 'Manual download required: https://www.malwarebytes.com/mwb-download' }"
)

:: 9. Try launching TrustedInstaller shell via gsudo --ti
if defined GSUDO_PATH (
    echo Launching TrustedInstaller command line via gsudo --ti...
    "%GSUDO_PATH%" --ti cmd /k "title %WIN_TITLE%"
    if !errorlevel! equ 0 goto :end_script
    echo [WARNING] gsudo --ti failed or was blocked. Trying PsExec fallback...
)

:: 10. Check or install PsExec
set "PSEXEC_PATH="
where psexec64 >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%I in ('where psexec64 2^>nul') do (
        if not defined PSEXEC_PATH set "PSEXEC_PATH=%%I"
    )
)
if not defined PSEXEC_PATH (
    where psexec >nul 2>&1
    if %errorlevel% equ 0 (
        for /f "delims=" %%I in ('where psexec 2^>nul') do (
            if not defined PSEXEC_PATH set "PSEXEC_PATH=%%I"
        )
    )
)
if not defined PSEXEC_PATH (
    if "%WINGET_READY%"=="1" (
        echo PsExec not found. Installing Microsoft Sysinternals PsExec via winget...
        winget install --id Microsoft.Sysinternals.PsExec -e --accept-source-agreements --accept-package-agreements
        if exist "%ProgramFiles%\Sysinternals\PsExec64.exe" (
            set "PSEXEC_PATH=%ProgramFiles%\Sysinternals\PsExec64.exe"
        ) else if exist "%ProgramFiles%\Sysinternals\PsExec.exe" (
            set "PSEXEC_PATH=%ProgramFiles%\Sysinternals\PsExec.exe"
        ) else (
            where psexec >nul 2>&1
            if %errorlevel% equ 0 (
                for /f "delims=" %%I in ('where psexec 2^>nul') do (
                    if not defined PSEXEC_PATH set "PSEXEC_PATH=%%I"
                )
            )
        )
    )
)

:: 11. Try launching system-level recovery command line via PsExec
if defined PSEXEC_PATH (
    echo Launching system-level recovery command line via PsExec...
    "%PSEXEC_PATH%" -accepteula -s -i cmd.exe /k "title %WIN_TITLE%"
    if !errorlevel! equ 0 goto :end_script
    echo [WARNING] PsExec execution failed or was blocked.
)

:: 12. Final fallback: Show window that computer likely cannot be recovered
echo [ERROR] Neither gsudo nor PsExec could launch a recovery shell.
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('The powerful privileges of the computer have been taken over by the virus. To run this software, you will now need to start Safe Mode with Networking. Start this image and run this file again.', 'Recovery Unavailable', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null"

:end_script
:: Re-enable Windows Defender Real-Time Monitoring before exit
powershell -NoProfile -Command "try { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue } catch {}"
endlocal
