# Start Docker at Windows startup

Auto-start Docker Desktop on boot. Pick the script that fits your setup.

## Scripts

| Script | Use Case |
|--------|----------|
| `Setup-DockerBootStart.bat` | Starts Docker service at boot + GUI at login |
| `Setup-AutoLoginDockerLock.bat` | windows Auto-login + start Docker + lock the screen |
| `Uninstall-DockerBootSetup.bat` | Detects and removes everything created by either script |

## Usage

1. Double-click the `.bat` file you need
2. Restart to test

## Uninstall

Double-click `Uninstall-DockerBootSetup.bat` — it will scan for scheduled tasks, files, and saved registry keys, and remove them.
