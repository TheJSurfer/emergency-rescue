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

:: 3. Open persistent higher privilege window (/k keeps it open so you can see status & use it)
if defined GSUDO_EXE (
    echo [PRIVILEGE] Opening persistent TrustedInstaller shell via gsudo --ti...
    start "TrustedInstaller Shell" "%GSUDO_EXE%" --ti cmd /k "title %WIN_TITLE% [TrustedInstaller] & echo ================================================== & echo [ACTIVE] TrustedInstaller Shell Ready & echo ================================================== & whoami /groups | findstr /i TrustedInstaller"
) else if defined PSEXEC_EXE (
    echo [PRIVILEGE] Opening persistent SYSTEM shell via PsExec...
    start "SYSTEM Shell" "%PSEXEC_EXE%" -accepteula -s -i cmd.exe /k "title %WIN_TITLE% [SYSTEM] & echo ================================================== & echo [ACTIVE] NT AUTHORITY\SYSTEM Shell Ready & echo ================================================== & whoami"
) else (
    echo [NOTICE] Neither gsudo.exe nor PsExec was found. Continuing with Administrator privileges...
)

:: 4. Run SFC /scannow; if issues remain, run DISM RestoreHealth then retry SFC
echo.
echo [REPAIR] Running SFC /scannow (please wait, output will stay visible)...
sfc /scannow
if errorlevel 1 (
    echo.
    echo [REPAIR] SFC detected integrity issues. Running DISM RestoreHealth...
    DISM /Online /Cleanup-Image /RestoreHealth
    echo.
    echo [REPAIR] Re-running SFC /scannow after DISM...
    sfc /scannow
)

:: 5. Launch Microsoft Windows Malicious Software Removal Tool (MRT) if present
echo.
if exist "%SystemRoot%\System32\mrt.exe" (
    echo [SCANNER] Launching Microsoft Windows Malicious Software Removal Tool...
    start "" "%SystemRoot%\System32\mrt.exe"
) else (
    echo [WARNING] mrt.exe not found in System32.
)

:: 6. Launch local Malwarebytes installer if present
set "MB_EXE=%SCRIPT_DIR%MBSetup.exe"
if not exist "%MB_EXE%" set "MB_EXE=%USERPROFILE%\Downloads\MBSetup.exe"
if exist "%MB_EXE%" (
    echo [SCANNER] Launching Malwarebytes installer...
    start "" "%MB_EXE%"
) else (
    echo [INFO] MBSetup.exe not found locally. Skipping Malwarebytes launch.
)

echo.
echo ====================================================================
echo [DONE] All recovery steps completed. No windows were auto-closed.
echo ====================================================================
cmd /k "title %WIN_TITLE%"
endlocal
