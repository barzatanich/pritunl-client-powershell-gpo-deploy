# GPO Startup App Installer (Auto-Updating)

A PowerShell 5.1–compatible **GPO Startup Script** that installs (or updates) a Windows application by comparing:
- the **installer EXE FileVersion** on a network share, and
- the **installed application EXE FileVersion** on the local machine.

If the installer is newer, it silently updates. If the app is missing, it performs a clean install.

## How it works

1. Creates a log folder under `C:\ProgramData\<OrgName>\Logs`.
2. Writes a `STARTED.txt` marker to confirm execution.
3. Waits for the installer path (UNC share) to become available (retries).
4. Reads installer EXE `FileVersion` from the share.
5. Reads local EXE `FileVersion` from the installed app path.
6. If server version `>` local version:
   - stops the running app process (optional),
   - runs the installer silently,
   - logs exit code and duration.
7. If local is already current, it exits with code `0`.

## Requirements

- Windows domain environment using **Group Policy**
- PowerShell 5.1 compatible execution environment
- Endpoints must be able to access the installer share at boot
- **Computer accounts** must have **read** permission to:
  - the script location (UNC path)
  - the installer location (UNC path)

## Configuration

Edit these values in the script:

- `InstallerPath`  
  `\\<server>\<share>\path\YourInstaller.exe`

- `LocalPath`  
  `C:\Program Files\YourApp\yourapp.exe`  
  *(or `C:\Program Files (x86)\...` depending on your app)*

- `InstallArgs`  
  Silent install flags for your installer (example uses Inno Setup style flags).

- `RetryCount`, `RetryDelay`  
  Helps when the network isn’t ready immediately at startup.

## GPO Setup (Startup Script)

Configure the script as a **Computer Startup Script**:

**Group Policy path:**
- `Computer Configuration`
  - `Policies`
    - `Windows Settings`
      - `Scripts (Startup/Shutdown)`
        - `Startup`

Add the script from a UNC path, for example:
- `\\<domain-or-fileserver>\<share>\Scripts\Install-App.ps1`

> Startup scripts run under the **Local System** account in the computer context.
> Ensure the **computer account** can read the script and installer from the share.

### Tip (reliability)
Consider enabling the policy:
- **Always wait for the network at computer startup and logon**
to improve consistency of share access during boot.

## Logging

Logs are written to:
- `C:\ProgramData\<OrgName>\Logs\App_Install.log`

Marker file:
- `C:\ProgramData\<OrgName>\Logs\STARTED.txt`

## Updating the installer (rollout procedure)

To deploy a new version:

1. Download the latest installer EXE.
2. Copy it to your share path used in `InstallerPath`.
3. **Keep the filename exactly the same** (overwrite the existing file).
4. Reboot endpoints (or wait for the next startup script run).

The script will detect the newer installer version and update automatically.

## License

MIT License. See `LICENSE`.
