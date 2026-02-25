@echo off
setlocal disabledelayedexpansion

:: =====================================================
:: Uninstall-DockerBootSetup.bat
:: Detects and removes everything created by either:
::   - Setup-DockerBootStart.bat
::   - Setup-AutoLoginDockerLock.bat
:: Double-click this file to run
:: =====================================================

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

title Uninstall Docker Boot Setup
color 0E

echo.
echo =====================================================
echo   Docker Boot Setup - Uninstaller
echo =====================================================
echo.
echo   This will detect and remove components created by:
echo     - Setup-DockerBootStart.bat
echo     - Setup-AutoLoginDockerLock.bat
echo.
echo.

set "FOUND_SOMETHING=0"

:: =====================================================
:: DETECTION PHASE
:: =====================================================
echo =====================================================
echo   Detection
echo =====================================================
echo.

:: --- Detect Scheduled Tasks ---
echo Checking for scheduled tasks...

:: Tasks from Setup-DockerBootStart.bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t=Get-ScheduledTask 'StartDockerServiceAtBoot' -EA 0; " ^
  "if($t){Write-Host '  [FOUND] StartDockerServiceAtBoot (State:' $t.State ')' -ForegroundColor Yellow; exit 1} " ^
  "else {Write-Host '  [  OK ] StartDockerServiceAtBoot - not present' -ForegroundColor DarkGray}"
if %ERRORLEVEL% equ 1 set "FOUND_SOMETHING=1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t=Get-ScheduledTask 'StartDockerDesktopAtLogin' -EA 0; " ^
  "if($t){Write-Host '  [FOUND] StartDockerDesktopAtLogin (State:' $t.State ')' -ForegroundColor Yellow; exit 1} " ^
  "else {Write-Host '  [  OK ] StartDockerDesktopAtLogin - not present' -ForegroundColor DarkGray}"
if %ERRORLEVEL% equ 1 set "FOUND_SOMETHING=1"

:: Tasks from Setup-AutoLoginDockerLock.bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t=Get-ScheduledTask 'DockerStartAndLockAfterAutoLogin' -EA 0; " ^
  "if($t){Write-Host '  [FOUND] DockerStartAndLockAfterAutoLogin (State:' $t.State ')' -ForegroundColor Yellow; exit 1} " ^
  "else {Write-Host '  [  OK ] DockerStartAndLockAfterAutoLogin - not present' -ForegroundColor DarkGray}"
if %ERRORLEVEL% equ 1 set "FOUND_SOMETHING=1"

:: Legacy task name from older versions
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t=Get-ScheduledTask 'LockScreenAfterAutoLogin' -EA 0; " ^
  "if($t){Write-Host '  [FOUND] LockScreenAfterAutoLogin (legacy) (State:' $t.State ')' -ForegroundColor Yellow; exit 1} " ^
  "else {Write-Host '  [  OK ] LockScreenAfterAutoLogin (legacy) - not present' -ForegroundColor DarkGray}"
if %ERRORLEVEL% equ 1 set "FOUND_SOMETHING=1"

echo.

:: --- Detect Folders ---
echo Checking for created folders...

if exist "C:\ProgramData\docker-autostart\" (
    echo   [FOUND] C:\ProgramData\docker-autostart\
    set "FOUND_SOMETHING=1"
) else (
    echo   [  OK ] C:\ProgramData\docker-autostart\ - not present
)

if exist "C:\ProgramData\AutoLoginLock\" (
    echo   [FOUND] C:\ProgramData\AutoLoginLock\
    set "FOUND_SOMETHING=1"
) else (
    echo   [  OK ] C:\ProgramData\AutoLoginLock\ - not present
)

echo.

:: --- Detect Auto-Login Registry ---
echo Checking for auto-login registry keys...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$r='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; " ^
  "$v=Get-ItemProperty $r -EA 0; " ^
  "if($v.AutoAdminLogon -eq '1'){ " ^
  "  Write-Host '  [FOUND] AutoAdminLogon is ENABLED' -ForegroundColor Yellow; " ^
  "  Write-Host '          Username:' $v.DefaultUsername -ForegroundColor Yellow; " ^
  "  Write-Host '          Domain:' $v.DefaultDomainName -ForegroundColor Yellow; " ^
  "  exit 1 " ^
  "} else { " ^
  "  Write-Host '  [  OK ] AutoAdminLogon is not enabled' -ForegroundColor DarkGray " ^
  "}"
if %ERRORLEVEL% equ 1 set "FOUND_SOMETHING=1"

echo.
echo =====================================================

:: =====================================================
:: CONFIRMATION
:: =====================================================
if "%FOUND_SOMETHING%"=="0" (
    echo.
    echo   Nothing to remove. System is clean!
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 0
)

echo.
echo   Remove all detected items? (y/n)
echo.
set /p confirm="  > "
if /i not "%confirm%"=="y" (
    echo.
    echo   Cancelled. Nothing was removed.
    echo.
    pause
    exit /b 0
)

echo.
echo =====================================================
echo   Removal
echo =====================================================
echo.

:: =====================================================
:: REMOVAL PHASE - Scheduled Tasks
:: =====================================================
echo [1/3] Removing scheduled tasks...
echo.


:: Remove: StartDockerServiceAtBoot
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t='StartDockerServiceAtBoot'; " ^
  "$e=Get-ScheduledTask $t -EA 0; " ^
  "if($e){ " ^
  "  Unregister-ScheduledTask $t -Confirm:$false; " ^
  "  Write-Host '  Removed:' $t -ForegroundColor Green " ^
  "} else { " ^
  "  Write-Host '  Skipped:' $t '(not found)' -ForegroundColor DarkGray " ^
  "}"

:: Remove: StartDockerDesktopAtLogin
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t='StartDockerDesktopAtLogin'; " ^
  "$e=Get-ScheduledTask $t -EA 0; " ^
  "if($e){ " ^
  "  Unregister-ScheduledTask $t -Confirm:$false; " ^
  "  Write-Host '  Removed:' $t -ForegroundColor Green " ^
  "} else { " ^
  "  Write-Host '  Skipped:' $t '(not found)' -ForegroundColor DarkGray " ^
  "}"

:: Remove: DockerStartAndLockAfterAutoLogin
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t='DockerStartAndLockAfterAutoLogin'; " ^
  "$e=Get-ScheduledTask $t -EA 0; " ^
  "if($e){ " ^
  "  Unregister-ScheduledTask $t -Confirm:$false; " ^
  "  Write-Host '  Removed:' $t -ForegroundColor Green " ^
  "} else { " ^
  "  Write-Host '  Skipped:' $t '(not found)' -ForegroundColor DarkGray " ^
  "}"

:: Remove: LockScreenAfterAutoLogin (legacy)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t='LockScreenAfterAutoLogin'; " ^
  "$e=Get-ScheduledTask $t -EA 0; " ^
  "if($e){ " ^
  "  Unregister-ScheduledTask $t -Confirm:$false; " ^
  "  Write-Host '  Removed:' $t '(legacy)' -ForegroundColor Green " ^
  "} else { " ^
  "  Write-Host '  Skipped:' $t '(legacy, not found)' -ForegroundColor DarkGray " ^
  "}"

echo.

:: =====================================================
:: REMOVAL PHASE - Folders and Files
:: =====================================================
echo [2/3] Removing files and folders...
echo.

:: Remove docker-autostart folder (from Setup-DockerBootStart.bat)
if exist "C:\ProgramData\docker-autostart\" (
    rmdir /s /q "C:\ProgramData\docker-autostart\"
    if not exist "C:\ProgramData\docker-autostart\" (
        echo   Removed: C:\ProgramData\docker-autostart\
    ) else (
        echo   WARNING: Could not fully remove C:\ProgramData\docker-autostart\
    )
) else (
    echo   Skipped: C:\ProgramData\docker-autostart\ ^(not found^)
)

:: Remove AutoLoginLock folder (from Setup-AutoLoginDockerLock.bat)
if exist "C:\ProgramData\AutoLoginLock\" (
    rmdir /s /q "C:\ProgramData\AutoLoginLock\"
    if not exist "C:\ProgramData\AutoLoginLock\" (
        echo   Removed: C:\ProgramData\AutoLoginLock\
    ) else (
        echo   WARNING: Could not fully remove C:\ProgramData\AutoLoginLock\
    )
) else (
    echo   Skipped: C:\ProgramData\AutoLoginLock\ ^(not found^)
)

echo.

:: =====================================================
:: REMOVAL PHASE - Auto-Login Registry
:: =====================================================
echo [3/3] Cleaning auto-login registry...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$r='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; " ^
  "$v=Get-ItemProperty $r -EA 0; " ^
  "if($v.AutoAdminLogon -eq '1'){ " ^
  "  Set-ItemProperty $r AutoAdminLogon 0; " ^
  "  Remove-ItemProperty $r DefaultPassword -EA 0; " ^
  "  Remove-ItemProperty $r ForceAutoLogon -EA 0; " ^
  "  Write-Host '  Auto-login disabled and password removed from registry.' -ForegroundColor Green " ^
  "} else { " ^
  "  Write-Host '  Auto-login not enabled. Nothing to clean.' -ForegroundColor DarkGray " ^
  "}"

:: =====================================================
:: VERIFICATION
:: =====================================================
echo.
echo =====================================================
echo   Verification (Post-Removal)
echo =====================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Write-Host 'Scheduled Tasks:' -ForegroundColor Cyan; " ^
  "$tasks=@('StartDockerServiceAtBoot','StartDockerDesktopAtLogin','DockerStartAndLockAfterAutoLogin','LockScreenAfterAutoLogin'); " ^
  "foreach($t in $tasks){ " ^
  "  $e=Get-ScheduledTask $t -EA 0; " ^
  "  if($e){Write-Host ('  ' + $t + ': STILL EXISTS') -ForegroundColor Red} " ^
  "  else {Write-Host ('  ' + $t + ': Removed') -ForegroundColor Green} " ^
  "}; " ^
  "Write-Host ''; " ^
  "Write-Host 'Folders:' -ForegroundColor Cyan; " ^
  "$folders=@('C:\ProgramData\docker-autostart','C:\ProgramData\AutoLoginLock'); " ^
  "foreach($f in $folders){ " ^
  "  if(Test-Path $f){Write-Host ('  ' + $f + ': STILL EXISTS') -ForegroundColor Red} " ^
  "  else {Write-Host ('  ' + $f + ': Removed') -ForegroundColor Green} " ^
  "}; " ^
  "Write-Host ''; " ^
  "Write-Host 'Auto-Login Registry:' -ForegroundColor Cyan; " ^
  "$r='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; " ^
  "$v=Get-ItemProperty $r -EA 0; " ^
  "if($v.AutoAdminLogon -eq '1'){Write-Host '  AutoAdminLogon: ENABLED' -ForegroundColor Yellow} " ^
  "else {Write-Host '  AutoAdminLogon: Disabled' -ForegroundColor Green}"

echo.
echo =====================================================
echo   Uninstall Complete!
echo =====================================================
echo.
echo   All detected Docker boot setup components have been
echo   removed from this system.
echo.
echo Press any key to exit...
pause >nul
