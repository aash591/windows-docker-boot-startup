@echo off
setlocal disabledelayedexpansion

:: Docker Desktop Auto-Start at Boot Setup (Batch Version)
:: Creates two scheduled tasks:
::   1. Docker Service at boot (runs as SYSTEM)
::   2. Docker Desktop GUI at login (runs as current user)
:: Double-click this file to run

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

title Docker Desktop Auto-Start at Boot Setup
color 0B

echo.
echo =====================================================
echo   Docker Desktop Auto-Start at Boot Setup
echo =====================================================
echo.
echo   Creates scheduled tasks to auto-start Docker
echo   service at boot and Docker Desktop GUI at login.
echo.

:: Step 1: Verify Docker Desktop installation
echo [1/5] Verifying Docker Desktop installation...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$dp = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'; " ^
  "if (Test-Path $dp) { " ^
  "  Write-Host 'Docker Desktop found at:' $dp -ForegroundColor Green " ^
  "} else { " ^
  "  Write-Host 'ERROR: Docker Desktop not found at:' $dp -ForegroundColor Red; " ^
  "  Write-Host 'Please install Docker Desktop first.' -ForegroundColor Yellow; " ^
  "  exit 1 " ^
  "}"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Docker Desktop is not installed
    pause
    exit /b 1
)

:: Step 2: Create folder
echo.
echo [2/5] Creating setup folder...
if not exist "C:\ProgramData\docker-autostart\" mkdir "C:\ProgramData\docker-autostart\"
echo Folder ready: C:\ProgramData\docker-autostart\

:: Step 3: Create Docker Service wrapper script
echo.
echo [3/5] Creating Docker service startup script...
set "SVC=C:\ProgramData\docker-autostart\DockerServiceStartWrapper.ps1"
>"%SVC%" echo # Docker Service Startup Wrapper Script
>>"%SVC%" echo # Runs at boot as SYSTEM to start the Docker service
>>"%SVC%" echo.
>>"%SVC%" echo $logPath = 'C:\ProgramData\docker-autostart\DockerStartup.log'
>>"%SVC%" echo.
>>"%SVC%" echo function Write-Log {
>>"%SVC%" echo     param([string]$message)
>>"%SVC%" echo     $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
>>"%SVC%" echo     $logMessage = '[' + $timestamp + '] [SERVICE] ' + $message
>>"%SVC%" echo     Add-Content -Path $logPath -Value $logMessage -ErrorAction SilentlyContinue
>>"%SVC%" echo     Write-Host $logMessage
>>"%SVC%" echo }
>>"%SVC%" echo.
>>"%SVC%" echo try {
>>"%SVC%" echo     Write-Log '=== Docker Service Startup Script Started ==='
>>"%SVC%" echo.
>>"%SVC%" echo     # Clean up Docker service log files that accumulate on each boot
>>"%SVC%" echo     $dockerDataPath = Join-Path $env:ProgramData 'Docker'
>>"%SVC%" echo     if (Test-Path $dockerDataPath) {
>>"%SVC%" echo         Write-Log 'Cleaning up old Docker service log files...'
>>"%SVC%" echo         Get-ChildItem -Path $dockerDataPath -Filter 'service*.txt' -ErrorAction SilentlyContinue ^| ForEach-Object {
>>"%SVC%" echo             Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
>>"%SVC%" echo             Write-Log ('Removed: ' + $_.Name)
>>"%SVC%" echo         }
>>"%SVC%" echo     }
>>"%SVC%" echo.
>>"%SVC%" echo     $dockerService = Get-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue
>>"%SVC%" echo     if ($dockerService) {
>>"%SVC%" echo         Write-Log ('Docker service found. Current status: ' + $dockerService.Status)
>>"%SVC%" echo.
>>"%SVC%" echo         if ($dockerService.Status -ne 'Running') {
>>"%SVC%" echo             Write-Log 'Starting Docker service...'
>>"%SVC%" echo             Start-Service -Name 'com.docker.service' -ErrorAction Stop
>>"%SVC%" echo             Start-Sleep -Seconds 3
>>"%SVC%" echo             Write-Log 'Docker service started successfully.'
>>"%SVC%" echo         } else {
>>"%SVC%" echo             Write-Log 'Docker service already running.'
>>"%SVC%" echo         }
>>"%SVC%" echo     } else {
>>"%SVC%" echo         Write-Log 'WARNING: Docker service not found.'
>>"%SVC%" echo         exit 1
>>"%SVC%" echo     }
>>"%SVC%" echo.
>>"%SVC%" echo     Write-Log '=== Docker Service Startup Script Completed ==='
>>"%SVC%" echo.
>>"%SVC%" echo } catch {
>>"%SVC%" echo     Write-Log ('ERROR: ' + $_.Exception.Message)
>>"%SVC%" echo     exit 1
>>"%SVC%" echo }

if not exist "%SVC%" (
    echo ERROR: Service wrapper script not created
    pause
    exit /b 1
)
echo Service script created: %SVC%

:: Step 4: Create Docker Desktop GUI wrapper script
echo.
echo [4/5] Creating Docker Desktop GUI startup script...
set "GUI=C:\ProgramData\docker-autostart\DockerGUIStartWrapper.ps1"
>"%GUI%" echo # Docker Desktop GUI Startup Wrapper Script
>>"%GUI%" echo # Runs at user login to launch Docker Desktop
>>"%GUI%" echo.
>>"%GUI%" echo $logPath = 'C:\ProgramData\docker-autostart\DockerStartup.log'
>>"%GUI%" echo.
>>"%GUI%" echo function Write-Log {
>>"%GUI%" echo     param([string]$message)
>>"%GUI%" echo     $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
>>"%GUI%" echo     $logMessage = '[' + $timestamp + '] [GUI] ' + $message
>>"%GUI%" echo     Add-Content -Path $logPath -Value $logMessage -ErrorAction SilentlyContinue
>>"%GUI%" echo     Write-Host $logMessage
>>"%GUI%" echo }
>>"%GUI%" echo.
>>"%GUI%" echo try {
>>"%GUI%" echo     Write-Log '=== Docker Desktop GUI Startup Script Started ==='
>>"%GUI%" echo.
>>"%GUI%" echo     Start-Sleep -Seconds 5
>>"%GUI%" echo.
>>"%GUI%" echo     $dockerProcess = Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue
>>"%GUI%" echo     if ($dockerProcess) {
>>"%GUI%" echo         Write-Log ('Docker Desktop is already running (PID: ' + $dockerProcess.Id + ').')
>>"%GUI%" echo         exit 0
>>"%GUI%" echo     }
>>"%GUI%" echo.
>>"%GUI%" echo     Write-Log 'Launching Docker Desktop GUI...'
>>"%GUI%" echo     $dockerPath = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
>>"%GUI%" echo.
>>"%GUI%" echo     if (Test-Path $dockerPath) {
>>"%GUI%" echo         Start-Process -FilePath $dockerPath -ErrorAction Stop
>>"%GUI%" echo         Write-Log 'Docker Desktop GUI started successfully.'
>>"%GUI%" echo     } else {
>>"%GUI%" echo         Write-Log ('ERROR: Docker Desktop executable not found at: ' + $dockerPath)
>>"%GUI%" echo         exit 1
>>"%GUI%" echo     }
>>"%GUI%" echo.
>>"%GUI%" echo     Write-Log '=== Docker Desktop GUI Startup Script Completed ==='
>>"%GUI%" echo.
>>"%GUI%" echo } catch {
>>"%GUI%" echo     Write-Log ('ERROR: ' + $_.Exception.Message)
>>"%GUI%" echo     exit 1
>>"%GUI%" echo }

if not exist "%GUI%" (
    echo ERROR: GUI wrapper script not created
    pause
    exit /b 1
)
echo GUI script created: %GUI%

:: Step 5: Create scheduled tasks
echo.
echo [5/5] Creating scheduled tasks...

:: Task 1: Docker Service at Boot (runs as SYSTEM)
echo.
echo Creating Task 1: Docker Service at Boot...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$t='StartDockerServiceAtBoot'; " ^
  "$s='C:\ProgramData\docker-autostart\DockerServiceStartWrapper.ps1'; " ^
  "$e=Get-ScheduledTask $t -EA 0; if($e){Unregister-ScheduledTask $t -Confirm:$false; Write-Host 'Removed existing service task.' -ForegroundColor Yellow}; " ^
  "$arg='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ' + $s; " ^
  "$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg; " ^
  "$tr=New-ScheduledTaskTrigger -AtStartup; " ^
  "$pr=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest; " ^
  "$se=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew; " ^
  "$se.ExecutionTimeLimit='PT0S'; " ^
  "$ta=New-ScheduledTask -Action $a -Trigger $tr -Principal $pr -Settings $se -Description 'Starts Docker service at system boot'; " ^
  "Register-ScheduledTask $t -InputObject $ta -Force | Out-Null; " ^
  "Write-Host 'Docker Service task created.' -ForegroundColor Green"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to create service task
    pause
    exit /b 1
)

:: Task 2: Docker Desktop GUI at Login (runs as current user)
echo.
echo Creating Task 2: Docker Desktop GUI at Login...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$u='%USERDOMAIN%\%USERNAME%'; " ^
  "$t='StartDockerDesktopAtLogin'; " ^
  "$s='C:\ProgramData\docker-autostart\DockerGUIStartWrapper.ps1'; " ^
  "$e=Get-ScheduledTask $t -EA 0; if($e){Unregister-ScheduledTask $t -Confirm:$false; Write-Host 'Removed existing GUI task.' -ForegroundColor Yellow}; " ^
  "$arg='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ' + $s; " ^
  "$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg; " ^
  "$tr=New-ScheduledTaskTrigger -AtLogOn -User $u; " ^
  "$pr=New-ScheduledTaskPrincipal -UserId $u -LogonType Interactive -RunLevel Highest; " ^
  "$se=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew; " ^
  "$se.ExecutionTimeLimit='PT0S'; " ^
  "$ta=New-ScheduledTask -Action $a -Trigger $tr -Principal $pr -Settings $se -Description 'Starts Docker Desktop GUI at user login'; " ^
  "Register-ScheduledTask $t -InputObject $ta -Force | Out-Null; " ^
  "Write-Host 'Docker Desktop GUI task created.' -ForegroundColor Green"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to create GUI task
    pause
    exit /b 1
)

:: Copy this batch file to the setup folder for reference
copy /Y "%~f0" "C:\ProgramData\docker-autostart\Setup-DockerAutoStart.bat" >nul 2>&1

:: Verification
echo.
echo =====================================================
echo   Verification
echo =====================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Write-Host 'Docker Desktop:' -ForegroundColor Cyan; " ^
  "$dp=Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'; " ^
  "Write-Host '  Installed:' (Test-Path $dp) -ForegroundColor Green; " ^
  "Write-Host ''; " ^
  "Write-Host 'Scheduled Tasks:' -ForegroundColor Cyan; " ^
  "$t1=Get-ScheduledTask 'StartDockerServiceAtBoot' -EA 0; " ^
  "if($t1){Write-Host '  Service Task:' $t1.State -ForegroundColor Green} else {Write-Host '  Service Task: NOT FOUND' -ForegroundColor Red}; " ^
  "$t2=Get-ScheduledTask 'StartDockerDesktopAtLogin' -EA 0; " ^
  "if($t2){Write-Host '  GUI Task:' $t2.State -ForegroundColor Green} else {Write-Host '  GUI Task: NOT FOUND' -ForegroundColor Red}; " ^
  "Write-Host ''; " ^
  "Write-Host 'Files:' -ForegroundColor Cyan; " ^
  "Write-Host '  Service Script:' (Test-Path 'C:\ProgramData\docker-autostart\DockerServiceStartWrapper.ps1') -ForegroundColor Green; " ^
  "Write-Host '  GUI Script:' (Test-Path 'C:\ProgramData\docker-autostart\DockerGUIStartWrapper.ps1') -ForegroundColor Green; " ^
  "Write-Host '  Log File: C:\ProgramData\docker-autostart\DockerStartup.log' -ForegroundColor White"

echo.
echo =====================================================
echo   Setup Complete!
echo =====================================================
echo.
echo   Task 1 - Docker Service:
echo     Name: StartDockerServiceAtBoot
echo     Runs at: System Startup (as SYSTEM)
echo.
echo   Task 2 - Docker Desktop GUI:
echo     Name: StartDockerDesktopAtLogin
echo     Runs at: User Login (as %USERDOMAIN%\%USERNAME%)
echo.
echo   Log File: C:\ProgramData\docker-autostart\DockerStartup.log
echo.
echo   To remove tasks:
echo     Run in PowerShell (Admin):
echo     Unregister-ScheduledTask -TaskName 'StartDockerServiceAtBoot' -Confirm:$false
echo     Unregister-ScheduledTask -TaskName 'StartDockerDesktopAtLogin' -Confirm:$false
echo.
echo Press any key to exit...
pause >nul
