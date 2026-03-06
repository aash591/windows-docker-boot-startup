@echo off
setlocal enabledelayedexpansion

:: Secure Auto-Login + Docker Desktop + Lock Setup
:: Uses LSA Secrets (encrypted) instead of plain-text registry password
:: Flow: Boot -> Auto-Login (LSA) -> Start Docker Desktop -> Wait for Engine -> Lock Screen
:: Double-click this file to run

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs" >nul 2>&1
    exit /b
)

title Secure Auto-Login + Docker Desktop + Lock Setup
color 0B

echo.
echo =====================================================
echo   Secure Auto-Login + Docker Desktop + Lock Setup
echo =====================================================
echo.
echo   Uses LSA Secrets for encrypted password storage.
echo   Designed for Windows Server where Docker Desktop
echo   requires an active login session to start.
echo.

:: Get username
set /p username="Enter username (local: username, domain: DOMAIN\username): "
if "%username%"=="" (
    echo ERROR: Username cannot be empty
    pause
    exit /b 1
)

:: Get password
echo.
set /p password="Enter password: "
if "%password%"=="" (
    echo ERROR: Password cannot be empty
    pause
    exit /b 1
)

echo.
echo =====================================================
echo   Configuring Secure Auto-Login + Docker Autostart...
echo =====================================================
echo.

:: ============================================================
:: Step 1: Configure LSA Secrets + Registry (via temp PS script)
:: ============================================================
echo [1/6] Configuring LSA secrets + registry...

set "psScript=%TEMP%\SecureDockerSetup_%RANDOM%.ps1"

(
echo $username = '%username%'
echo $password = '%password%'
echo $ErrorActionPreference = 'Stop'
echo.
echo # Parse username
echo $domain = $env:COMPUTERNAME
echo $user = $username
echo if ^($username.Contains^('\\'^)^) {
echo     $parts = $username.Split^('\\'^)
echo     $domain = $parts[0]
echo     $user = $parts[1]
echo     if ^($domain -eq '.'^) { $domain = $env:COMPUTERNAME }
echo }
echo.
echo try {
echo     Add-Type -TypeDefinition @"
echo using System;
echo using System.Runtime.InteropServices;
echo.
echo public class LSAUtil {
echo     [StructLayout^(LayoutKind.Sequential^)]
echo     private struct LSA_UNICODE_STRING {
echo         public UInt16 Length;
echo         public UInt16 MaximumLength;
echo         public IntPtr Buffer;
echo     }
echo.
echo     [StructLayout^(LayoutKind.Sequential^)]
echo     private struct LSA_OBJECT_ATTRIBUTES {
echo         public int Length;
echo         public IntPtr RootDirectory;
echo         public LSA_UNICODE_STRING ObjectName;
echo         public uint Attributes;
echo         public IntPtr SecurityDescriptor;
echo         public IntPtr SecurityQualityOfService;
echo     }
echo.
echo     private enum LSA_AccessPolicy : long {
echo         POLICY_CREATE_SECRET = 0x00000020L
echo     }
echo.
echo     [DllImport^("advapi32.dll", SetLastError = true, PreserveSig = true^)]
echo     private static extern uint LsaStorePrivateData^(
echo         IntPtr policyHandle,
echo         ref LSA_UNICODE_STRING KeyName,
echo         ref LSA_UNICODE_STRING PrivateData
echo     ^);
echo.
echo     [DllImport^("advapi32.dll", SetLastError = true, PreserveSig = true^)]
echo     private static extern uint LsaOpenPolicy^(
echo         ref LSA_UNICODE_STRING SystemName,
echo         ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
echo         uint DesiredAccess,
echo         out IntPtr PolicyHandle
echo     ^);
echo.
echo     [DllImport^("advapi32.dll", SetLastError = true, PreserveSig = true^)]
echo     private static extern uint LsaClose^(IntPtr ObjectHandle^);
echo.
echo     private static void InitLsaString^(ref LSA_UNICODE_STRING lsaString, string s^) {
echo         if ^(s == null^) {
echo             lsaString.Buffer = IntPtr.Zero;
echo             lsaString.Length = 0;
echo             lsaString.MaximumLength = 0;
echo         } else {
echo             lsaString.Buffer = Marshal.StringToHGlobalUni^(s^);
echo             lsaString.Length = ^(UInt16^)^(s.Length * sizeof^(char^)^);
echo             lsaString.MaximumLength = ^(UInt16^)^(^(s.Length + 1^) * sizeof^(char^)^);
echo         }
echo     }
echo.
echo     public static void SetSecret^(string key, string value^) {
echo         LSA_UNICODE_STRING system = default^(LSA_UNICODE_STRING^);
echo         LSA_OBJECT_ATTRIBUTES attribs = new LSA_OBJECT_ATTRIBUTES^(^);
echo         attribs.Length = Marshal.SizeOf^(typeof^(LSA_OBJECT_ATTRIBUTES^)^);
echo.        
echo         IntPtr handle = IntPtr.Zero;
echo         uint result = LsaOpenPolicy^(ref system, ref attribs, 
echo             ^(uint^)LSA_AccessPolicy.POLICY_CREATE_SECRET, out handle^);
echo.        
echo         if ^(result ^^!= 0^) throw new Exception^("LsaOpenPolicy failed"^);
echo.
echo         LSA_UNICODE_STRING lusKey = default^(LSA_UNICODE_STRING^);
echo         LSA_UNICODE_STRING lusValue = default^(LSA_UNICODE_STRING^);
echo         InitLsaString^(ref lusKey, key^);
echo         InitLsaString^(ref lusValue, value^);
echo.
echo         result = LsaStorePrivateData^(handle, ref lusKey, ref lusValue^);
echo         LsaClose^(handle^);
echo.
echo         if ^(result ^^!= 0^) throw new Exception^("LsaStorePrivateData failed"^);
echo     }
echo }
echo "@
echo.
echo     # Store in LSA
echo     [LSAUtil]::SetSecret^("DefaultPassword", $password^)
echo     Write-Host "  [1/6] LSA secrets configured (encrypted)" -ForegroundColor Green
echo.
echo     # Configure registry
echo     $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
echo     Set-ItemProperty -Path $regPath -Name 'AutoAdminLogon' -Value '1' -Type String
echo     Set-ItemProperty -Path $regPath -Name 'DefaultUsername' -Value $user -Type String
echo     Set-ItemProperty -Path $regPath -Name 'DefaultDomainName' -Value $domain -Type String
echo     Set-ItemProperty -Path $regPath -Name 'ForceAutoLogon' -Value '0' -Type String
echo     Remove-ItemProperty -Path $regPath -Name 'DefaultPassword' -ErrorAction SilentlyContinue
echo     Write-Host "  [2/6] Registry configured (password NOT in registry)" -ForegroundColor Green
echo.
echo } catch {
echo     Write-Host ""
echo     Write-Host "ERROR: $^($_.Exception.Message^)" -ForegroundColor Red
echo     exit 1
echo }
) > "%psScript%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%psScript%"

set lsaExitCode=!ERRORLEVEL!
del "%psScript%" >nul 2>&1

if !lsaExitCode! neq 0 (
    echo.
    echo ERROR: Failed to configure LSA secrets and registry
    pause
    exit /b 1
)

:: ============================================================
:: Step 2: Verify Docker Desktop installation
:: ============================================================
echo.
echo [3/6] Verifying Docker Desktop installation...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$dockerPath = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'; " ^
  "if (Test-Path $dockerPath) { " ^
  "  Write-Host '  Docker Desktop found at:' $dockerPath -ForegroundColor Green " ^
  "} else { " ^
  "  Write-Host '  WARNING: Docker Desktop not found.' -ForegroundColor Yellow; " ^
  "  Write-Host '  Install Docker Desktop before rebooting.' -ForegroundColor Yellow " ^
  "}"

:: ============================================================
:: Step 3: Create setup folder
:: ============================================================
echo.
echo [4/6] Creating setup folder...
if not exist "C:\ProgramData\DockerAutoStart\" mkdir "C:\ProgramData\DockerAutoStart\"
echo   Folder ready: C:\ProgramData\DockerAutoStart\

:: ============================================================
:: Step 4: Create Docker startup + lock script
:: ============================================================
echo.
echo [5/6] Creating Docker startup + lock script...
set "PS1=C:\ProgramData\DockerAutoStart\LockAfterLogin.ps1"
>"%PS1%" echo # ============================================================
>>"%PS1%" echo # LockAfterLogin.ps1
>>"%PS1%" echo # Runs at login: Start Docker Desktop, wait for engine, then lock
>>"%PS1%" echo # Secure version: Password stored in LSA Secrets (encrypted)
>>"%PS1%" echo # ============================================================
>>"%PS1%" echo.
>>"%PS1%" echo $logFile = 'C:\ProgramData\DockerAutoStart\AutoLoginLock.log'
>>"%PS1%" echo $dockerExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
>>"%PS1%" echo $maxWaitSeconds = 120
>>"%PS1%" echo.
>>"%PS1%" echo function Write-Log {
>>"%PS1%" echo     param([string]$msg)
>>"%PS1%" echo     $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
>>"%PS1%" echo     $entry = '[' + $ts + '] ' + $msg
>>"%PS1%" echo     Add-Content -Path $logFile -Value $entry -ErrorAction SilentlyContinue
>>"%PS1%" echo }
>>"%PS1%" echo.
>>"%PS1%" echo Write-Log '========== Script started ==========='
>>"%PS1%" echo Write-Log 'Waiting 5 seconds for desktop to initialize...'
>>"%PS1%" echo Start-Sleep -Seconds 5
>>"%PS1%" echo.
>>"%PS1%" echo # --- Step 1: Start Docker Desktop ---
>>"%PS1%" echo Write-Log 'Checking if Docker Desktop is already running...'
>>"%PS1%" echo $dockerProc = Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue
>>"%PS1%" echo if ($dockerProc) {
>>"%PS1%" echo     Write-Log ('Docker Desktop already running (PID: ' + $dockerProc.Id + ')')
>>"%PS1%" echo } else {
>>"%PS1%" echo     if (Test-Path $dockerExe) {
>>"%PS1%" echo         Write-Log ('Starting Docker Desktop from: ' + $dockerExe)
>>"%PS1%" echo         Start-Process -FilePath $dockerExe
>>"%PS1%" echo         Write-Log 'Docker Desktop process launched.'
>>"%PS1%" echo         Start-Sleep -Seconds 10
>>"%PS1%" echo     } else {
>>"%PS1%" echo         Write-Log ('ERROR: Docker Desktop not found at ' + $dockerExe)
>>"%PS1%" echo         Write-Log 'Skipping Docker startup, proceeding to lock.'
>>"%PS1%" echo         rundll32.exe user32.dll,LockWorkStation
>>"%PS1%" echo         exit 1
>>"%PS1%" echo     }
>>"%PS1%" echo }
>>"%PS1%" echo.
>>"%PS1%" echo # --- Step 2: Wait for Docker engine to be ready ---
>>"%PS1%" echo Write-Log ('Waiting up to ' + $maxWaitSeconds + ' seconds for Docker engine...')
>>"%PS1%" echo $elapsed = 0
>>"%PS1%" echo $ready = $false
>>"%PS1%" echo while ($elapsed -lt $maxWaitSeconds) {
>>"%PS1%" echo     try {
>>"%PS1%" echo         $null = docker info 2^>^&1
>>"%PS1%" echo         if ($LASTEXITCODE -eq 0) {
>>"%PS1%" echo             $ready = $true
>>"%PS1%" echo             break
>>"%PS1%" echo         }
>>"%PS1%" echo     } catch { }
>>"%PS1%" echo     Start-Sleep -Seconds 5
>>"%PS1%" echo     $elapsed += 5
>>"%PS1%" echo     if (($elapsed %% 15) -eq 0) {
>>"%PS1%" echo         Write-Log ('Still waiting... (' + $elapsed + ' seconds elapsed)')
>>"%PS1%" echo     }
>>"%PS1%" echo }
>>"%PS1%" echo.
>>"%PS1%" echo if ($ready) {
>>"%PS1%" echo     Write-Log ('Docker engine is ready after ' + $elapsed + ' seconds.')
>>"%PS1%" echo } else {
>>"%PS1%" echo     Write-Log ('WARNING: Docker engine not ready after ' + $maxWaitSeconds + ' seconds. Locking anyway.')
>>"%PS1%" echo }
>>"%PS1%" echo.
>>"%PS1%" echo # --- Step 3: Lock the workstation ---
>>"%PS1%" echo Write-Log 'Locking workstation now...'
>>"%PS1%" echo rundll32.exe user32.dll,LockWorkStation
>>"%PS1%" echo Start-Sleep -Seconds 2
>>"%PS1%" echo Write-Log '========== Script completed ==========='

if not exist "%PS1%" (
    echo ERROR: Script file not created
    pause
    exit /b 1
)
echo   Script created: %PS1%

:: ============================================================
:: Step 5: Create scheduled task
:: ============================================================
echo.
echo [6/6] Creating scheduled task...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$u='%username%'; " ^
  "$t='DockerStartAndLockAfterAutoLogin'; " ^
  "$s='C:\ProgramData\DockerAutoStart\LockAfterLogin.ps1'; " ^
  "$e=Get-ScheduledTask $t -EA 0; if($e){Unregister-ScheduledTask $t -Confirm:$false}; " ^
  "$oldTask=Get-ScheduledTask 'LockScreenAfterAutoLogin' -EA 0; if($oldTask){Unregister-ScheduledTask 'LockScreenAfterAutoLogin' -Confirm:$false; Write-Host 'Removed old LockScreenAfterAutoLogin task.' -ForegroundColor Yellow}; " ^
  "$arg='-NoProfile -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File ' + $s; " ^
  "$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg; " ^
  "$tr=New-ScheduledTaskTrigger -AtLogOn -User $u; " ^
  "$tr.Delay='PT5S'; " ^
  "$pr=New-ScheduledTaskPrincipal -UserId $u -LogonType Interactive -RunLevel Highest; " ^
  "$se=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew; " ^
  "$se.ExecutionTimeLimit='PT5M'; " ^
  "$ta=New-ScheduledTask -Action $a -Trigger $tr -Principal $pr -Settings $se -Description 'Secure auto-login: Start Docker Desktop and lock screen'; " ^
  "Register-ScheduledTask $t -InputObject $ta -Force | Out-Null; " ^
  "Write-Host '  Scheduled task created.' -ForegroundColor Green"

if !ERRORLEVEL! neq 0 (
    echo ERROR: Failed to create scheduled task
    pause
    exit /b 1
)

:: ============================================================
:: Verification
:: ============================================================
echo.
echo =====================================================
echo   Verification
echo =====================================================
echo.
setlocal DisableDelayedExpansion
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$r='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; " ^
  "$v=Get-ItemProperty $r; " ^
  "$hasPlain=[bool]$v.DefaultPassword; " ^
  "Write-Host 'Registry Settings:' -ForegroundColor Cyan; " ^
  "Write-Host '  AutoAdminLogon:' $v.AutoAdminLogon -ForegroundColor Green; " ^
  "Write-Host '  ForceAutoLogon:' $v.ForceAutoLogon -ForegroundColor Yellow; " ^
  "Write-Host '  Username:' $v.DefaultUsername; " ^
  "Write-Host '  Domain:' $v.DefaultDomainName; " ^
  "Write-Host '  Password in registry:' -NoNewline; " ^
  "if($hasPlain){Write-Host ' YES (INSECURE)' -ForegroundColor Red}else{Write-Host ' NO (LSA encrypted)' -ForegroundColor Green}; " ^
  "Write-Host ''; " ^
  "Write-Host 'Docker Desktop:' -ForegroundColor Cyan; " ^
  "$dp=Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'; " ^
  "Write-Host '  Installed:' (Test-Path $dp) -ForegroundColor Green; " ^
  "Write-Host ''; " ^
  "Write-Host 'Scheduled Task:' -ForegroundColor Cyan; " ^
  "$tc=Get-ScheduledTask 'DockerStartAndLockAfterAutoLogin' -EA 0; " ^
  "if($tc){Write-Host '  Task Status:' $tc.State -ForegroundColor Green} else {Write-Host '  Task: NOT FOUND' -ForegroundColor Red}; " ^
  "Write-Host '  Script exists:' (Test-Path 'C:\ProgramData\DockerAutoStart\LockAfterLogin.ps1') -ForegroundColor Green"

if %ERRORLEVEL% neq 0 (
    echo.
    echo WARNING: Verification reported an error. Setup is complete, but review output above.
)
endlocal

echo.
echo.
echo =====================================================
echo   Setup Complete!
echo =====================================================
echo.
echo What happens on boot:
echo   1. PC boots and auto-logs in (LSA encrypted password)
echo   2. Waits 5 seconds for desktop to initialize
echo   3. Starts Docker Desktop
echo   4. Waits up to 120 seconds for Docker engine to be ready
echo   5. Locks the screen automatically
echo   6. Docker continues running behind the lock screen
echo.
echo Check logs after reboot:
echo   C:\ProgramData\DockerAutoStart\AutoLoginLock.log
echo.
echo Press any key to exit...
pause >nul
