@echo off
setlocal disabledelayedexpansion

:: Windows Auto-Login + Docker Desktop + Lock Setup
:: Designed for Windows Server where Docker needs a login session
:: Flow: Boot -> Auto-Login -> Start Docker Desktop -> Wait for Engine -> Lock Screen
:: Double-click this file to run

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

title Windows Auto-Login + Docker Desktop + Lock Setup
color 0B

echo.
echo =====================================================
echo   Windows Auto-Login + Docker Desktop + Lock Setup
echo =====================================================
echo.
echo   Designed for Windows Server where Docker Desktop
echo   requires an active login session to start.
echo.
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
echo   Configuring Auto-Login + Docker Autostart...
echo =====================================================
echo.

:: Step 1: Configure Registry for Auto-Login
:: NOTE: ForceAutoLogon is set to 0 intentionally.
::       Setting it to 1 causes auto-login after EVERY lock/signout, not just boot.
echo [1/5] Configuring auto-login registry...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$u='%username%'; $p='%password%'; " ^
  "$d=$env:COMPUTERNAME; $us=$u; " ^
  "if($u -match '\\\\'){$parts=$u -split '\\\\'; $d=$parts[0]; $us=$parts[1]; if($d -eq '.'){$d=$env:COMPUTERNAME}}; " ^
  "Write-Host 'Domain:' $d; Write-Host 'User:' $us; " ^
  "$r='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; " ^
  "Set-ItemProperty $r AutoAdminLogon 1; " ^
  "Set-ItemProperty $r DefaultUsername $us; " ^
  "Set-ItemProperty $r DefaultPassword $p; " ^
  "Set-ItemProperty $r DefaultDomainName $d; " ^
  "Set-ItemProperty $r ForceAutoLogon 0; " ^
  "Write-Host 'Registry configured.' -ForegroundColor Green"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to configure registry
    pause
    exit /b 1
)

:: Step 2: Verify Docker Desktop installation
echo.
echo [2/5] Verifying Docker Desktop installation...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$dockerPath = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'; " ^
  "if (Test-Path $dockerPath) { " ^
  "  Write-Host 'Docker Desktop found at:' $dockerPath -ForegroundColor Green " ^
  "} else { " ^
  "  Write-Host 'ERROR: Docker Desktop not found at:' $dockerPath -ForegroundColor Red; " ^
  "  Write-Host 'Please install Docker Desktop first.' -ForegroundColor Yellow; " ^
  "  exit 1 " ^
  "}"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Docker Desktop is not installed
    pause
    exit /b 1
)

:: Step 3: Create folder
echo.
echo [3/5] Creating setup folder...
if not exist "C:\ProgramData\AutoLoginLock\" mkdir "C:\ProgramData\AutoLoginLock\"
echo Folder ready: C:\ProgramData\AutoLoginLock\

:: Step 4: Create the login script (Docker Start + Lock)
echo.
echo [4/5] Creating Docker startup + lock script...
set "PS1=C:\ProgramData\AutoLoginLock\LockAfterLogin.ps1"
>"%PS1%" echo # ============================================================
>>"%PS1%" echo # LockAfterLogin.ps1
>>"%PS1%" echo # Runs at login: Start Docker Desktop, wait for engine, then lock
>>"%PS1%" echo # Designed for Windows Server where Docker needs a login session
>>"%PS1%" echo # ============================================================
>>"%PS1%" echo.
>>"%PS1%" echo $logFile = 'C:\ProgramData\AutoLoginLock\AutoLoginLock.log'
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
echo Script created: %PS1%

:: Step 5: Create scheduled task
echo.
echo [5/5] Creating scheduled task...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$u='%username%'; " ^
  "$t='DockerStartAndLockAfterAutoLogin'; " ^
  "$s='C:\ProgramData\AutoLoginLock\LockAfterLogin.ps1'; " ^
  "$e=Get-ScheduledTask $t -EA 0; if($e){Unregister-ScheduledTask $t -Confirm:$false}; " ^
  "$oldTask=Get-ScheduledTask 'LockScreenAfterAutoLogin' -EA 0; if($oldTask){Unregister-ScheduledTask 'LockScreenAfterAutoLogin' -Confirm:$false; Write-Host 'Removed old LockScreenAfterAutoLogin task.' -ForegroundColor Yellow}; " ^
  "$arg='-NoProfile -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File ' + $s; " ^
  "$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg; " ^
  "$tr=New-ScheduledTaskTrigger -AtLogOn -User $u; " ^
  "$tr.Delay='PT5S'; " ^
  "$pr=New-ScheduledTaskPrincipal -UserId $u -LogonType Interactive -RunLevel Highest; " ^
  "$se=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew; " ^
  "$se.ExecutionTimeLimit='PT5M'; " ^
  "$ta=New-ScheduledTask -Action $a -Trigger $tr -Principal $pr -Settings $se -Description 'Start Docker Desktop and lock screen after auto-login'; " ^
  "Register-ScheduledTask $t -InputObject $ta -Force | Out-Null; " ^
  "Write-Host 'Scheduled task created.' -ForegroundColor Green"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to create scheduled task
    pause
    exit /b 1
)

:: Verification
echo.
echo =====================================================
echo   Verification
echo =====================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$r='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; " ^
  "$v=Get-ItemProperty $r; " ^
  "Write-Host 'Registry Settings:' -ForegroundColor Cyan; " ^
  "Write-Host '  AutoAdminLogon:' $v.AutoAdminLogon -ForegroundColor Green; " ^
  "Write-Host '  ForceAutoLogon:' $v.ForceAutoLogon -ForegroundColor Yellow; " ^
  "Write-Host '  Username:' $v.DefaultUsername; " ^
  "Write-Host '  Domain:' $v.DefaultDomainName; " ^
  "Write-Host ''; " ^
  "Write-Host 'Docker Desktop:' -ForegroundColor Cyan; " ^
  "$dp=Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'; " ^
  "Write-Host '  Installed:' (Test-Path $dp) -ForegroundColor Green; " ^
  "Write-Host ''; " ^
  "Write-Host 'Scheduled Task:' -ForegroundColor Cyan; " ^
  "$tc=Get-ScheduledTask 'DockerStartAndLockAfterAutoLogin' -EA 0; " ^
  "if($tc){Write-Host '  Task Status:' $tc.State -ForegroundColor Green} else {Write-Host '  Task: NOT FOUND' -ForegroundColor Red}; " ^
  "Write-Host '  Script exists:' (Test-Path 'C:\ProgramData\AutoLoginLock\LockAfterLogin.ps1') -ForegroundColor Green"

echo.
echo =====================================================
echo   SECURITY WARNING
echo =====================================================
echo Password is stored in registry (plain text)
echo.
echo =====================================================
echo   Setup Complete!
echo =====================================================
echo.
echo What happens on boot:
echo   1. PC boots and auto-logs in as %username%
echo   2. Waits 5 seconds for desktop to initialize
echo   3. Starts Docker Desktop
echo   4. Waits up to 120 seconds for Docker engine to be ready
echo   5. Locks the screen automatically
echo   6. Docker continues running behind the lock screen
echo.
echo Check logs after reboot:
echo   C:\ProgramData\AutoLoginLock\AutoLoginLock.log
echo.
echo Press any key to exit...
pause >nul
