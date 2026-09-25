@echo off
setlocal
cd /d "%~dp0"

:: Check if directory contains tally_ledger_desktop
if exist "%~dp0tally_ledger_desktop\tally_ledger_desktop.exe" (
    start "" /d "%~dp0tally_ledger_desktop" "%~dp0tally_ledger_desktop\tally_ledger_desktop.exe"
    exit /b 0
)

if exist "%~dp0tally_ledger_desktop.exe" (
    start "" /d "%~dp0" "%~dp0tally_ledger_desktop.exe"
    exit /b 0
)

echo [ERROR] Tally Ledger executable not found on this USB drive.
echo Please ensure tally_ledger_desktop.exe is placed in the USB directory.
pause
