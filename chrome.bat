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

:: Refresh common paths first
if exist "%ProgramFiles%\gsudo\Current\gsudo.exe" (
    set "PATH=%ProgramFiles%\gsudo\Current;%PATH%"
)
if exist "%ProgramFiles%\Sysinternals\PsExec64.exe" (
    set "PATH=%ProgramFiles%\Sysinternals;%PATH%"
)
if exist "%ProgramFiles%\Sysinternals\PsExec.exe" (
    set "PATH=%ProgramFiles%\Sysinternals;%PATH%"
)

:: Check if winget is available and active
set "WINGET_READY=0"
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget --info >nul 2>&1
    if %errorlevel% equ 0 (
        set "WINGET_READY=1"
    )
)

:: 1. Check if gsudo is already installed; if not and winget is active, install it
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

:: Try launching TrustedInstaller shell via gsudo --ti
if defined GSUDO_PATH (
    echo Launching TrustedInstaller command line via gsudo --ti...
    "%GSUDO_PATH%" --ti cmd /k "title %WIN_TITLE%"
    if %errorlevel% equ 0 goto :end_script
    echo [WARNING] gsudo --ti failed or was blocked. Trying PsExec fallback...
)

:: 2. Check if PsExec is already installed; if not and winget is active, install Sysinternals PsExec
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

:: Try launching system-level recovery command line via PsExec
if defined PSEXEC_PATH (
    echo Launching system-level recovery command line via PsExec...
    "%PSEXEC_PATH%" -accepteula -s -i cmd.exe /k "title %WIN_TITLE%"
    if %errorlevel% equ 0 goto :end_script
    echo [WARNING] PsExec execution failed or was blocked.
)

:: 3. Final fallback: Show window that computer likely cannot be recovered
echo [ERROR] Neither gsudo nor PsExec could launch a recovery shell.
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('The computer is likely not in a state to be recovered.', 'Recovery Unavailable', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null"

:end_script
endlocal
