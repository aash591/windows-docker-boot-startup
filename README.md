# Run Docker Desktop at Windows Startup Scripts

Run one setup `.bat` as Administrator, then reboot.

## Script Flow

| Script | Flow (key steps) |
|---|---|
| `Setup-DockerBootStart.bat` | Check Docker Desktop -> create `DockerServiceStartWrapper.ps1` + `DockerGUIStartWrapper.ps1` -> create tasks `StartDockerServiceAtBoot` (SYSTEM, startup) and `StartDockerDesktopAtLogin` (user login) -> log to `DockerStartup.log`. |
| `Setup-AutoLoginDockerLock.bat` | Prompt user/password -> enable Winlogon auto-login (**password in registry**) -> create `LockAfterLogin.ps1` -> task `DockerStartAndLockAfterAutoLogin` at login -> start Docker Desktop -> wait up to 120s for engine -> lock workstation. |
| `Setup-SecureAutoLoginDockerLock.bat` | Prompt user/password -> store password in LSA secret (**not plain-text registry**) -> create `LockAfterLogin.ps1` -> task `DockerStartAndLockAfterAutoLogin` at login -> start Docker Desktop -> wait up to 120s -> lock workstation. |
| `Uninstall-DockerBootSetup.bat` | Detect created tasks/files/auto-login settings -> ask `y/n` -> remove tasks + `C:\ProgramData\DockerAutoStart\` -> disable auto-login -> clean registry password + attempt LSA secret cleanup -> verify removal. |

Common output path: `C:\ProgramData\DockerAutoStart\`
