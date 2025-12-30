# Docker Desktop Auto-Start at Boot Script
# Run this script as Administrator
# Creates two tasks: one for Docker service at boot, one for GUI at login

# Define the task details
$serviceTaskName = "StartDockerServiceAtBoot"
$guiTaskName = "StartDockerDesktopAtLogin"
$taskDescription = "Starts Docker service at boot and Docker Desktop GUI at user login."
$scriptFolder = Join-Path $env:ProgramData "docker-autostart"
$serviceWrapperPath = Join-Path $scriptFolder "DockerServiceStartWrapper.ps1"
$guiWrapperPath = Join-Path $scriptFolder "DockerGUIStartWrapper.ps1"
$logPath = Join-Path $scriptFolder "DockerStartup.log"

try {
    # Check if running as Administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "This script requires Administrator privileges." -ForegroundColor Yellow
        Write-Host "Would you like to restart it as Administrator? (Y/N)" -ForegroundColor Cyan
        $response = Read-Host
        
        if ($response -eq 'Y' -or $response -eq 'y') {
            # Get the script path
            $scriptPath = $MyInvocation.MyCommand.Path
            if (-not $scriptPath) {
                $scriptPath = $PSCommandPath
            }
            
            # Restart the script as Administrator
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
            exit
        } else {
            Write-Host "Script cancelled. Administrator privileges are required to create scheduled tasks." -ForegroundColor Red
            pause
            exit 1
        }
    }

    # Get current user's full username for the principal
    $userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host "Creating scheduled tasks for user: $userId" -ForegroundColor Cyan

    # Check if the tasks already exist and remove them to avoid conflicts
    $existingServiceTask = Get-ScheduledTask -TaskName $serviceTaskName -ErrorAction SilentlyContinue
    if ($existingServiceTask) {
        Unregister-ScheduledTask -TaskName $serviceTaskName -Confirm:$false
        Write-Host "Existing service task removed to allow recreation." -ForegroundColor Yellow
    }
    
    $existingGuiTask = Get-ScheduledTask -TaskName $guiTaskName -ErrorAction SilentlyContinue
    if ($existingGuiTask) {
        Unregister-ScheduledTask -TaskName $guiTaskName -Confirm:$false
        Write-Host "Existing GUI task removed to allow recreation." -ForegroundColor Yellow
    }

    # Verify Docker Desktop installation
    $dockerPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (-not (Test-Path $dockerPath)) {
        Write-Host "ERROR: Docker Desktop not found at: $dockerPath" -ForegroundColor Red
        Write-Host "Please verify Docker Desktop is installed." -ForegroundColor Yellow
        pause
        exit 1
    }

    # Create script folder if it doesn't exist
    if (-not (Test-Path $scriptFolder)) {
        New-Item -Path $scriptFolder -ItemType Directory -Force | Out-Null
        Write-Host "Created folder: $scriptFolder" -ForegroundColor Green
    }

    # Copy this setup script to the docker-autostart folder for future reference
    $currentScriptPath = $MyInvocation.MyCommand.Path
    if (-not $currentScriptPath) {
        $currentScriptPath = $PSCommandPath
    }
    if ($currentScriptPath) {
        $setupScriptDestination = Join-Path $scriptFolder "Setup-DockerAutoStart.ps1"
        if ($currentScriptPath -ne $setupScriptDestination) {
            Copy-Item -Path $currentScriptPath -Destination $setupScriptDestination -Force -ErrorAction SilentlyContinue
            Write-Host "Setup script copied to: $setupScriptDestination" -ForegroundColor Green
        }
    }

    # Create wrapper script for Docker SERVICE (runs at boot)
    $serviceWrapperContent = @"
# Docker Service Startup Wrapper Script
`$logPath = "$logPath"

function Write-Log {
    param([string]`$message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logMessage = "[`$timestamp] [SERVICE] `$message"
    Add-Content -Path `$logPath -Value `$logMessage -ErrorAction SilentlyContinue
    Write-Host `$logMessage
}

try {
    Write-Log "=== Docker Service Startup Script Started ==="
    
    # Clean up Docker's service log files that accumulate on each boot
    `$dockerDataPath = "`$env:ProgramData\Docker"
    if (Test-Path `$dockerDataPath) {
        Write-Log "Cleaning up old Docker service log files..."
        Get-ChildItem -Path `$dockerDataPath -Filter "service*.txt" -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item `$_.FullName -Force -ErrorAction SilentlyContinue
            Write-Log "Removed: `$(`$_.Name)"
        }
    }
    
    `$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
    if (`$dockerService) {
        Write-Log "Docker service found. Current status: `$(`$dockerService.Status)"
        
        if (`$dockerService.Status -ne 'Running') {
            Write-Log "Starting Docker service..."
            Start-Service -Name "com.docker.service" -ErrorAction Stop
            Start-Sleep -Seconds 3
            Write-Log "Docker service started successfully."
        } else {
            Write-Log "Docker service already running."
        }
    } else {
        Write-Log "WARNING: Docker service not found."
        exit 1
    }
    
    Write-Log "=== Docker Service Startup Script Completed ==="
    
} catch {
    Write-Log "ERROR: `$(`$_.Exception.Message)"
    exit 1
}
"@

    # Create wrapper script for Docker DESKTOP GUI (runs at login)
    $guiWrapperContent = @"
# Docker Desktop GUI Startup Wrapper Script
`$logPath = "$logPath"

function Write-Log {
    param([string]`$message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logMessage = "[`$timestamp] [GUI] `$message"
    Add-Content -Path `$logPath -Value `$logMessage -ErrorAction SilentlyContinue
    Write-Host `$logMessage
}

try {
    Write-Log "=== Docker Desktop GUI Startup Script Started ==="
    
    Start-Sleep -Seconds 5
    
    `$dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
    if (`$dockerProcess) {
        Write-Log "Docker Desktop is already running (PID: `$(`$dockerProcess.Id))."
        exit 0
    }
    
    Write-Log "Launching Docker Desktop GUI..."
    `$dockerPath = "`$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    
    if (Test-Path `$dockerPath) {
        Start-Process -FilePath `$dockerPath -ErrorAction Stop
        Write-Log "Docker Desktop GUI started successfully."
    } else {
        Write-Log "ERROR: Docker Desktop executable not found at: `$dockerPath"
        exit 1
    }
    
    Write-Log "=== Docker Desktop GUI Startup Script Completed ==="
    
} catch {
    Write-Log "ERROR: `$(`$_.Exception.Message)"
    exit 1
}
"@

    # Write wrapper scripts
    $serviceWrapperContent | Out-File -FilePath $serviceWrapperPath -Encoding UTF8 -Force
    Write-Host "Service wrapper script created at: $serviceWrapperPath" -ForegroundColor Green
    
    $guiWrapperContent | Out-File -FilePath $guiWrapperPath -Encoding UTF8 -Force
    Write-Host "GUI wrapper script created at: $guiWrapperPath" -ForegroundColor Green

    Write-Host "`nCreating Task 1: Docker Service at Boot..." -ForegroundColor Cyan
    
    # Task 1: Docker Service at Boot
    $serviceAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$serviceWrapperPath`""
    $serviceTrigger = New-ScheduledTaskTrigger -AtStartup
    $servicePrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $serviceSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
    $serviceSettings.ExecutionTimeLimit = "PT0S"
    
    $serviceTask = New-ScheduledTask -Action $serviceAction -Trigger $serviceTrigger -Principal $servicePrincipal -Settings $serviceSettings -Description "Starts Docker service at system boot"
    Register-ScheduledTask -TaskName $serviceTaskName -InputObject $serviceTask -Force | Out-Null
    Write-Host "Docker Service task created successfully!" -ForegroundColor Green

    Write-Host "`nCreating Task 2: Docker Desktop GUI at Login..." -ForegroundColor Cyan
    
    # Task 2: Docker Desktop GUI at Login
    $guiAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$guiWrapperPath`""
    $guiTrigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
    $guiPrincipal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
    $guiSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
    $guiSettings.ExecutionTimeLimit = "PT0S"
    
    $guiTask = New-ScheduledTask -Action $guiAction -Trigger $guiTrigger -Principal $guiPrincipal -Settings $guiSettings -Description "Starts Docker Desktop GUI at user login"
    Register-ScheduledTask -TaskName $guiTaskName -InputObject $guiTask -Force | Out-Null
    Write-Host "Docker Desktop GUI task created successfully!" -ForegroundColor Green

    # Verify tasks were created
    $verifyServiceTask = Get-ScheduledTask -TaskName $serviceTaskName -ErrorAction SilentlyContinue
    $verifyGuiTask = Get-ScheduledTask -TaskName $guiTaskName -ErrorAction SilentlyContinue
    
    if ($verifyServiceTask -and $verifyGuiTask) {
        Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
        Write-Host "Both scheduled tasks created successfully!" -ForegroundColor Green
        Write-Host "`nTask 1 - Docker Service:" -ForegroundColor Cyan
        Write-Host "  Name: $serviceTaskName" -ForegroundColor White
        Write-Host "  Runs at: System Startup (as SYSTEM)" -ForegroundColor White
        Write-Host "  Purpose: Start Docker service" -ForegroundColor White
        Write-Host "`nTask 2 - Docker Desktop GUI:" -ForegroundColor Cyan
        Write-Host "  Name: $guiTaskName" -ForegroundColor White
        Write-Host "  Runs at: User Login" -ForegroundColor White
        Write-Host "  User: $userId" -ForegroundColor White
        Write-Host "  Purpose: Start Docker Desktop GUI" -ForegroundColor White
        Write-Host "`nFiles Created:" -ForegroundColor Cyan
        Write-Host "  Service Script: $serviceWrapperPath" -ForegroundColor White
        Write-Host "  GUI Script: $guiWrapperPath" -ForegroundColor White
        Write-Host "  Log File: $logPath" -ForegroundColor White
        Write-Host "`nDocker service will start at boot, GUI will start when you login." -ForegroundColor Green
        Write-Host "`nTo test:" -ForegroundColor Yellow
        Write-Host "  1. Log out and log back in (to test GUI startup)" -ForegroundColor White
        Write-Host "  2. Or restart your computer (to test both)" -ForegroundColor White
        Write-Host "  3. Check the log file at: $logPath" -ForegroundColor White
        Write-Host "`nTo manually run tasks:" -ForegroundColor Yellow
        Write-Host "  Service: Start-ScheduledTask -TaskName '$serviceTaskName'" -ForegroundColor White
        Write-Host "  GUI: Start-ScheduledTask -TaskName '$guiTaskName'" -ForegroundColor White
        Write-Host "`nTo remove tasks:" -ForegroundColor Yellow
        Write-Host "  Unregister-ScheduledTask -TaskName '$serviceTaskName' -Confirm:`$false" -ForegroundColor White
        Write-Host "  Unregister-ScheduledTask -TaskName '$guiTaskName' -Confirm:`$false" -ForegroundColor White
    } else {
        Write-Host "`nERROR: Task creation verification failed!" -ForegroundColor Red
        if (-not $verifyServiceTask) {
            Write-Host "  Service task was not created" -ForegroundColor Red
        }
        if (-not $verifyGuiTask) {
            Write-Host "  GUI task was not created" -ForegroundColor Red
        }
    }

} catch {
    Write-Host "`nERROR: Failed to create scheduled tasks" -ForegroundColor Red
    Write-Host "Error Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
pause
