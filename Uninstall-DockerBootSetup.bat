@echo off
setlocal disabledelayedexpansion

:: =====================================================
:: Uninstall-DockerBootSetup.bat
:: Detects and removes everything created by:
::   - Setup-DockerBootStart.bat
::   - Setup-AutoLoginDockerLock.bat
::   - Setup-SecureAutoLoginDockerLock.bat
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
echo     - Setup-SecureAutoLoginDockerLock.bat
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

:: Tasks from Setup-AutoLoginDockerLock.bat / Setup-SecureAutoLoginDockerLock.bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t=Get-ScheduledTask 'DockerStartAndLockAfterAutoLogin' -EA 0; " ^
  "if($t){Write-Host '  [FOUND] DockerStartAndLockAfterAutoLogin (State:' $t.State ')' -ForegroundColor Yellow; exit 1} " ^
  "else {Write-Host '  [  OK ] DockerStartAndLockAfterAutoLogin - not present' -ForegroundColor DarkGray}"
if %ERRORLEVEL% equ 1 set "FOUND_SOMETHING=1"

echo.

:: --- Detect Folders ---
echo Checking for created folders...

if exist "C:\ProgramData\DockerAutoStart\" (
    echo   [FOUND] C:\ProgramData\DockerAutoStart\
    set "FOUND_SOMETHING=1"
) else (
    echo   [  OK ] C:\ProgramData\DockerAutoStart\ - not present
)

:: Detect secure setup marker in login script (created by Setup-SecureAutoLoginDockerLock.bat)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p='C:\ProgramData\DockerAutoStart\LockAfterLogin.ps1'; " ^
  "if(Test-Path $p){ " ^
  "  $secure=Select-String -Path $p -Pattern 'Secure version: Password stored in LSA Secrets' -SimpleMatch -Quiet -EA 0; " ^
  "  if($secure){Write-Host '  [FOUND] Secure setup marker in LockAfterLogin.ps1 (LSA mode)' -ForegroundColor Yellow; exit 1} " ^
  "  else {Write-Host '  [  OK ] Secure setup marker - not detected' -ForegroundColor DarkGray} " ^
  "} else { " ^
  "  Write-Host '  [  OK ] Secure setup marker - script not present' -ForegroundColor DarkGray " ^
  "}"
if %ERRORLEVEL% equ 1 set "FOUND_SOMETHING=1"

echo.

:: --- Detect Auto-Login Registry ---
echo Checking for auto-login registry keys...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$r='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; " ^
  "$v=Get-ItemProperty $r -EA 0; " ^
  "$hasPlain=[bool]$v.DefaultPassword; " ^
  "if($v.AutoAdminLogon -eq '1'){ " ^
  "  Write-Host '  [FOUND] AutoAdminLogon is ENABLED' -ForegroundColor Yellow; " ^
  "  Write-Host '          Username:' $v.DefaultUsername -ForegroundColor Yellow; " ^
  "  Write-Host '          Domain:' $v.DefaultDomainName -ForegroundColor Yellow; " ^
  "  if($hasPlain){Write-Host '          Password Source: Registry (standard auto-login setup)' -ForegroundColor Yellow} " ^
  "  else {Write-Host '          Password Source: LSA secret or external policy (secure setup compatible)' -ForegroundColor Yellow} " ^
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
    echo   Nothing to remove!
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

echo.

:: =====================================================
:: REMOVAL PHASE - Folders and Files
:: =====================================================
echo [2/3] Removing files and folders...
echo.

:: Remove shared setup folder (from all setup scripts) - ProgramData (current)
if exist "C:\ProgramData\DockerAutoStart\" (
    rmdir /s /q "C:\ProgramData\DockerAutoStart\"
    if not exist "C:\ProgramData\DockerAutoStart\" (
        echo   Removed: C:\ProgramData\DockerAutoStart\
    ) else (
        echo   WARNING: Could not fully remove C:\ProgramData\DockerAutoStart\
    )
) else (
    echo   Skipped: C:\ProgramData\DockerAutoStart\ ^(not found^)
)

echo.

:: =====================================================
:: REMOVAL PHASE - Auto-Login Registry
:: =====================================================
echo [3/3] Cleaning auto-login credentials and registry...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$r='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; " ^
  "$v=Get-ItemProperty $r -EA 0; " ^
  "if($v.AutoAdminLogon -eq '1'){ " ^
  "  Set-ItemProperty $r AutoAdminLogon 0; " ^
  "  Remove-ItemProperty $r DefaultPassword -EA 0; " ^
  "  Remove-ItemProperty $r ForceAutoLogon -EA 0; " ^
  "  Write-Host '  Auto-login disabled and registry credentials cleaned.' -ForegroundColor Green " ^
  "} else { " ^
  "  Write-Host '  Auto-login not enabled. Nothing to clean.' -ForegroundColor DarkGray " ^
  "}"

:: Remove secure auto-login password from LSA secret store (Setup-SecureAutoLoginDockerLock.bat)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { " ^
  "  $code='using System; using System.Runtime.InteropServices; public class LSASecretCleanup { [StructLayout(LayoutKind.Sequential)] public struct LSA_UNICODE_STRING { public UInt16 Length; public UInt16 MaximumLength; public IntPtr Buffer; } [StructLayout(LayoutKind.Sequential)] public struct LSA_OBJECT_ATTRIBUTES { public Int32 Length; public IntPtr RootDirectory; public LSA_UNICODE_STRING ObjectName; public UInt32 Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService; } [DllImport(\"advapi32.dll\", SetLastError=true, PreserveSig=true)] private static extern UInt32 LsaOpenPolicy(ref LSA_UNICODE_STRING SystemName, ref LSA_OBJECT_ATTRIBUTES ObjectAttributes, UInt32 DesiredAccess, out IntPtr PolicyHandle); [DllImport(\"advapi32.dll\", SetLastError=true, PreserveSig=true)] private static extern UInt32 LsaStorePrivateData(IntPtr PolicyHandle, ref LSA_UNICODE_STRING KeyName, IntPtr PrivateData); [DllImport(\"advapi32.dll\", SetLastError=true, PreserveSig=true)] private static extern UInt32 LsaClose(IntPtr ObjectHandle); [DllImport(\"advapi32.dll\", SetLastError=true, PreserveSig=true)] private static extern UInt32 LsaNtStatusToWinError(UInt32 Status); private static void InitLsaString(ref LSA_UNICODE_STRING s, String v) { if(v==null){ s.Length=0; s.MaximumLength=0; s.Buffer=IntPtr.Zero; return; } s.Buffer=Marshal.StringToHGlobalUni(v); s.Length=(UInt16)(v.Length*2); s.MaximumLength=(UInt16)((v.Length+1)*2); } public static UInt32 DeleteSecret(String key) { LSA_UNICODE_STRING sys=new LSA_UNICODE_STRING(); LSA_OBJECT_ATTRIBUTES oa=new LSA_OBJECT_ATTRIBUTES(); oa.Length=Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES)); IntPtr h; UInt32 st=LsaOpenPolicy(ref sys, ref oa, 0x00000020, out h); if(st!=0){ return st; } LSA_UNICODE_STRING k=new LSA_UNICODE_STRING(); InitLsaString(ref k, key); st=LsaStorePrivateData(h, ref k, IntPtr.Zero); LsaClose(h); return st; } public static UInt32 NtStatusToWinErrorCode(UInt32 st) { return LsaNtStatusToWinError(st); } }'; " ^
  "  Add-Type -TypeDefinition $code -EA Stop; " ^
  "  $st=[LSASecretCleanup]::DeleteSecret('DefaultPassword'); " ^
  "  if($st -eq 0){ " ^
  "    Write-Host '  Removed: LSA secret DefaultPassword' -ForegroundColor Green " ^
  "  } elseif($st -eq 0xC0000034){ " ^
  "    Write-Host '  Skipped: LSA secret DefaultPassword (not found)' -ForegroundColor DarkGray " ^
  "  } else { " ^
  "    $win=[LSASecretCleanup]::NtStatusToWinErrorCode($st); " ^
  "    Write-Host ('  WARNING: Could not remove LSA secret DefaultPassword (NTSTATUS: 0x{0:X8}, Win32: {1})' -f $st, $win) -ForegroundColor Yellow " ^
  "  } " ^
  "} catch { " ^
  "  Write-Host ('  WARNING: LSA secret cleanup failed: ' + $_.Exception.Message) -ForegroundColor Yellow " ^
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
  "$tasks=@('StartDockerServiceAtBoot','StartDockerDesktopAtLogin','DockerStartAndLockAfterAutoLogin'); " ^
  "foreach($t in $tasks){ " ^
  "  $e=Get-ScheduledTask $t -EA 0; " ^
  "  if($e){Write-Host ('  ' + $t + ': STILL EXISTS') -ForegroundColor Red} " ^
  "  else {Write-Host ('  ' + $t + ': Removed') -ForegroundColor Green} " ^
  "}; " ^
  "Write-Host ''; " ^
  "Write-Host 'Folders:' -ForegroundColor Cyan; " ^
  "$folders=@('C:\ProgramData\DockerAutoStart'); " ^
  "foreach($f in $folders){ " ^
  "  if(Test-Path $f){Write-Host ('  ' + $f + ': STILL EXISTS') -ForegroundColor Red} " ^
  "  else {Write-Host ('  ' + $f + ': Removed') -ForegroundColor Green} " ^
  "}; " ^
  "Write-Host ''; " ^
  "Write-Host 'Auto-Login Registry:' -ForegroundColor Cyan; " ^
  "$r='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; " ^
  "$v=Get-ItemProperty $r -EA 0; " ^
  "$hasPlain=[bool]$v.DefaultPassword; " ^
  "if($v.AutoAdminLogon -eq '1'){Write-Host '  AutoAdminLogon: ENABLED' -ForegroundColor Yellow} " ^
  "else {Write-Host '  AutoAdminLogon: Disabled' -ForegroundColor Green}; " ^
  "if($hasPlain){Write-Host '  DefaultPassword in registry: PRESENT' -ForegroundColor Yellow} " ^
  "else {Write-Host '  DefaultPassword in registry: Not present' -ForegroundColor Green}; " ^
  "Write-Host '  LSA secret DefaultPassword: removal attempted in step [3/3].' -ForegroundColor DarkGray"

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
