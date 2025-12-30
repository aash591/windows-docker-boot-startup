# Docker Desktop Auto-Start for Windows

Automatically start Docker at boot and show the GUI when you login.

## Quick Start

**Option 1 (Easiest):**
1. Right-click `Setup-DockerAutoStart.ps1`
2. Select "Run with PowerShell"
3. Click "Yes" when prompted to run as Administrator

**Option 2:**
1. Run PowerShell as Administrator
2. Execute: `.\Setup-DockerAutoStart.ps1`

Then restart your computer or log out/in to test.

## What It Does

- ✅ Starts Docker service at boot (before login)
- ✅ Opens Docker Desktop GUI when you login
- ✅ Creates log file at `C:\ProgramData\docker-autostart\DockerStartup.log`

## Remove

```powershell
Unregister-ScheduledTask -TaskName "StartDockerServiceAtBoot" -Confirm:$false
Unregister-ScheduledTask -TaskName "StartDockerDesktopAtLogin" -Confirm:$false
```

## Test Manually

```powershell
# Test GUI
Start-ScheduledTask -TaskName "StartDockerDesktopAtLogin"

# Check logs
Get-Content C:\ProgramData\DockerStartup.log
```


