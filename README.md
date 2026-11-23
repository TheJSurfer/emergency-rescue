# `chrome.bat` — Emergency Ultimate Privilege & System Recovery Shell

[![Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/)
[![Privilege](https://img.shields.io/badge/Privilege-TrustedInstaller%20%26%20NT%20AUTHORITY%5CSYSTEM-critical?style=for-the-badge&logo=shield&logoColor=white)](https://github.com/)
[![Engine](https://img.shields.io/badge/Engine-Zero--Dependency%20Batch%20%2B%20WinGet%20%2B%20Sysinternals-success?style=for-the-badge&logo=gnubash&logoColor=white)](https://github.com/)
[![Status](https://img.shields.io/badge/Status-Battle--Tested%20Emergency%20Tool-blueviolet?style=for-the-badge)](https://github.com/)

> **"When malware locks your doors, disables your tools, and strips away your Administrator rights — you don't need another scanner. You need absolute, unrestricted kernel-adjacent authority to take your machine back."**

---

## Why `chrome.bat` Exists (And Why You Should Keep It Before You Need It)

Modern malware, ransomware droppers, rogue group policies, and persistent rootkits rarely stop at infecting files. The very first thing sophisticated threats do is **hijack system control**:
- They strip standard Administrator privileges from your user session.
- They lock critical registry hives (`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options`, `Policies`, `Run`).
- They protect malicious services and scheduled tasks under **`NT AUTHORITY\SYSTEM`** or **`NT SERVICE\TrustedInstaller`** ownership so even an elevated Administrator receives **`Access is denied`**.
- They rename or block common recovery utilities before you even realize your system has been compromised.

**`chrome.bat`** is a lightweight, zero-bloat, tactical emergency recovery launcher engineered for the exact moment a Windows machine is under siege. Named intentionally as `chrome.bat` to bypass naive process-name blocklists and basic behavioral filters, it executes a multi-stage privilege escalation pipeline to hand you back **unrestricted command-line control** over your operating system.

---

## Multi-Stage Tactical Escalation Architecture

Unlike ordinary scripts that crash the moment a single dependency is missing or blocked, **`chrome.bat`** operates on an intelligent **3-Tier Fail-Safe Recovery Pipeline**:

    ┌─────────────────────────────────────────────────────────────────────────┐
    │ LAUNCH: chrome.bat │
    │ Auto-detects & requests Administrator UAC Elevation │
    └───────────────────────────────────┬─────────────────────────────────────┘
                                        │
                                        ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ TIER 1: Pre-Installed Tool Detection & WinGet Health Verification │
    │ • Scans system PATH & standard directories for gsudo & PsExec │
    │ • Probes Windows Package Manager (winget) availability & live status │
    └───────────────────────────────────┬─────────────────────────────────────┘
                                        │
                                        ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ TIER 2: TrustedInstaller Shell via gsudo (--ti) │
    │ • Uses existing gsudo OR silently deploys gerardog.gsudo via winget │
    │ • Launches CMD directly inside NT SERVICE\TrustedInstaller context │
    │ • Title: "This is the powerful command line to take control..." │
    └───────────────────────────────────┬─────────────────────────────────────┘
                                        │ (If blocked or unavailable)
                                        ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ TIER 3: Kernel-Level SYSTEM Fallback via Microsoft Sysinternals PsExec │
    │ • Uses existing PsExec OR deploys Microsoft.Sysinternals.PsExec │
    │ • Executes: psexec -accepteula -s -i cmd.exe │
    │ • Grants interactive NT AUTHORITY\SYSTEM recovery shell │
    └───────────────────────────────────┬─────────────────────────────────────┘
                                        │ (If completely compromised)
                                        ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ FINAL FAILSAFE: Critical System State Alert │
    │ • Displays native Windows GUI diagnostic alert informing the user │
    │ that the OS environment is too damaged for live user-mode recovery │
    └─────────────────────────────────────────────────────────────────────────┘

---

## Core Capabilities & Engineering Highlights

### 1. Instant `TrustedInstaller` Token Acquisition (`gsudo --ti`)
In Windows architecture, **`TrustedInstaller`** holds higher file-system and registry ownership than even the built-in `Administrator` account. By leveraging `gsudo --ti`, `chrome.bat` spawns a Command Prompt where `Access is denied` on protected Windows system binaries, hijacked DLLs, and locked registry keys ceases to be an obstacle.

### 2. Smart Pre-Installation & Zero-Redundancy Check
Time is critical during an active infection or system lockout. Before touching the network or invoking package managers, `chrome.bat` inspects:
- Active environment `PATH` variables
- `%ProgramFiles%\gsudo\Current\`
- `%ProgramFiles%\Sysinternals\`

If **`gsudo`** or **`PsExec`** is already present on the machine, it executes **immediately offline** without wasting a single second downloading packages.

### 3. Autonomous `winget` Provisioning
If the recovery utilities are not yet installed, `chrome.bat` verifies whether **Windows Package Manager (`winget`)** is present and responsive (`winget --info`), then silently provisions:
- `gerardog.gsudo` (Primary TrustedInstaller elevation engine)
- `Microsoft.Sysinternals.PsExec` (Official Microsoft Sysinternals fallback engine)

### 4. Microsoft Sysinternals `PsExec` (`NT AUTHORITY\SYSTEM`) Fallback
If malware or system corruption prevents `gsudo --ti` from initializing, the script automatically pivots to **Microsoft Sysinternals `PsExec`** (`-accepteula -s -i`), elevating your console directly to **`NT AUTHORITY\SYSTEM`** — the highest local security principal in the Windows kernel security model.

### 5. Unmistakable Command Authority Banner
The launched recovery console is immediately branded with a clear, high-visibility title so you know you are inside the unrestricted recovery environment:
> `This is the powerful command line to take control of your computer. Whatever you give here will run.`

### 6. Honest Diagnostic Failsafe
If an active rootkit or severe OS corruption has completely destroyed `winget`, `gsudo`, and `PsExec` execution paths simultaneously, `chrome.bat` refuses to fail silently — it triggers a native Windows GUI dialog alerting you immediately that live recovery is compromised and offline boot/WinRE intervention is required.

---

## Source Code (`chrome.bat`)

    @echo off
    setlocal EnableDelayedExpansion

    :: Set the requested English window title
    set "WIN_TITLE=This is the powerful command line to take control of your computer. Whatever you give here will run."
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

---

## How to Use `chrome.bat`

### Quick Start (Emergency Mode)
1. Download **`chrome.bat`** from this repository and keep a backup copy on your desktop, an emergency USB drive, or a secondary partition.
2. **Double-click `chrome.bat`** (or right-click -> **Run as administrator**).
3. Approve the Windows UAC prompt if requested.
4. Wait a few seconds while `chrome.bat` verifies your environment and opens your elevated **`TrustedInstaller` / `SYSTEM`** command console.

### Verify Your Privilege Level Inside the Shell
Once the new command window opens, run:

    whoami /groups | findstr /i "TrustedInstaller System"

If you see **`NT SERVICE\TrustedInstaller`** or **`NT AUTHORITY\SYSTEM`** listed with `Enabled group`, you now hold total administrative mastery over the operating system.

---

## Emergency Recovery Commands You Can Run Immediately

Once inside the `chrome.bat` recovery shell, you can execute critical remediation commands that normally fail in standard Command Prompt:

| Recovery Objective | Command to Execute |
| :--- | :--- |
| **Inspect running processes & parent PIDs** | `wmic process get name,processid,parentprocessid,executablepath` |
| **Force-kill stubborn malicious processes** | `taskkill /F /IM <malicious_process.exe> /T` |
| **Disable & delete hijacked Windows services** | `sc stop <ServiceName> && sc delete <ServiceName>` |
| **Unlock & delete protected malware files** | `takeown /F "<Path>" /A && icacls "<Path>" /grant Administrators:F && del /F /Q "<Path>"` |
| **Remove rogue Task Manager / Regedit blocks** | `reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /f` |
| **Repair corrupted Windows system files** | `sfc /scannow && DISM /Online /Cleanup-Image /RestoreHealth` |
| **Launch Registry Editor as TrustedInstaller** | `regedit.exe` |
| **Launch Task Manager as TrustedInstaller** | `taskmgr.exe` |

---

## Important Security & Responsible Use Notice

- **With Great Power Comes Total Responsibility:** A shell running under `TrustedInstaller` or `NT AUTHORITY\SYSTEM` bypasses standard Windows file and registry protections. Every command you type executes immediately without safety rails. Always double-check paths before running `del`, `rd`, or `reg delete`.
- **Anti-Malware & Defender Behavior:** Because `chrome.bat` programmatically orchestrates privilege elevation tools (`gsudo` and `Sysinternals PsExec`), certain heuristic antivirus engines may flag the script or its child tools as dual-use administrative utilities. Review the clean, transparent source code directly in `chrome.bat` to verify every single line.
- **When Live Recovery Is Not Enough:** If a boot-sector rootkit or kernel-mode driver has completely disabled Windows user-mode execution and `chrome.bat` triggers its final diagnostic alert, boot into **Windows Recovery Environment (WinRE)** or use a clean external rescue USB.

---

## Stay Ahead of System Lockouts & Cyber Emergencies

System administration, Windows internals, privilege recovery, and emergency defense tools evolve constantly.

- **Star this repository** right now so you never lose track of `chrome.bat` when an emergency hits.
- **Follow my GitHub profile** for upcoming releases, deeper Windows recovery automation, defensive batch/PowerShell toolkits, and real-world system rescue utilities.
- **Fork & Contribute** if you want to propose additional offline recovery fallbacks or defensive checks.

---

**Built for defenders, power users, and anyone who refuses to lose control of their own machine.**  
*Keep `chrome.bat` ready — before you ever need it.*
