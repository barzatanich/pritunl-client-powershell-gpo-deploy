# pritunl-client-powershell-gpo-deploy

A PowerShell 5.1–compatible **GPO Startup Script** to install and auto-update the **Pritunl Client** on Windows endpoints.

The script compares:
- the **installer EXE FileVersion** on a network share, and
- the **installed `pritunl.exe` FileVersion** on the local machine

If the installer version is newer, the script silently updates Pritunl. If Pritunl is not installed, it performs a clean install.

---

## What it does

At computer startup (via GPO), the script:

1. Creates a logging directory under `C:\ProgramData\Pritunl\Logs`.
2. Writes a marker file to prove the script started (`Pritunl_STARTED.txt`).
3. Waits for the installer share path to become available (retry loop).
4. Reads the **FileVersion** of the installer EXE on the share.
5. Detects local Pritunl installation by checking common `pritunl.exe` paths.
6. Compares installer version vs local version:
   - If installer `>` local: runs silent update
   - If local not found: runs silent install
   - If local is current: exits with no changes
7. Stops the running `pritunl` process (if present) before installing/updating.
8. Runs the installer silently and logs exit code and duration.

---

## Requirements

- Windows domain environment using **Group Policy**
- **PowerShell 5.1**
- Endpoints must be able to access the installer share during boot
- **Computer accounts** must have read access to:
  - the script location (UNC path)
  - the installer location (UNC path)

---

## Configuration

Edit **only** the installer share path in the script:

- `InstallerPath`  
  Example: `\\fileserver\software\Pritunl\Pritunl_Setup.exe`

Keep the installer filename consistent if you want hands-off updates (see the update procedure below).

---

## Local Pritunl path (version detection)

The script checks for `pritunl.exe` in these standard locations:

- `C:\Program Files\Pritunl\pritunl.exe`
- `C:\Program Files (x86)\Pritunl\pritunl.exe`

Whichever path exists first is used for the version comparison.

---

## Silent install arguments

The script uses:

- `/VERYSILENT /NORESTART`

These flags are commonly used by installers built with Inno Setup. If your Pritunl installer requires different flags, update `InstallArgs` in the script.

---

## GPO setup (Startup Script)

Configure the script as a **Computer Startup Script**:

**Group Policy path:**
- `Computer Configuration`
  - `Policies`
    - `Windows Settings`
      - `Scripts (Startup/Shutdown)`
        - `Startup`

Add the PowerShell script from a UNC path, for example:
- `\\<domain-or-fileserver>\<share>\Scripts\Install-Pritunl.ps1`

**Parameters:** none

> Startup scripts run under the **Local System** account (computer context).  
> Make sure the **computer account** can read both the script and the installer from the network share.

### Reliability tip
For more consistent network availability at boot, consider enabling:
- **Always wait for the network at computer startup and logon**

---

## Logging and verification

Logs are written to:

- `C:\ProgramData\Pritunl\Logs\Pritunl_Install.log`

A marker file is created each run:

- `C:\ProgramData\Pritunl\Logs\Pritunl_STARTED.txt`

The log includes:
- share/installer version
- detected local version (if present)
- decision (install/update/exit)
- installer exit code
- elapsed time

---

## Updating the installer (rolling out a new version)

To deploy a new Pritunl version to all machines:

1. Download the newest Pritunl Windows installer (EXE).
2. Copy it to the share path used in `InstallerPath`.
3. **Name it exactly the same** as referenced by the script (example: `Pritunl_Setup.exe`).
4. Overwrite/replace the existing file.

At the next reboot (or next startup-script execution), endpoints will compare versions and update automatically if the share installer is newer.

---

## Troubleshooting

### Installer not found / share not available
Symptoms:
- Log shows repeated “Waiting for network path…” messages
- Then “Installer not found after retries. Aborting.”

Checks:
- Can the endpoint reach the UNC path during boot?
- Do **computer accounts** have read permission on the share and file?

### Script runs but does nothing
Check:
- `C:\ProgramData\Pritunl\Logs\Pritunl_Install.log`
- Confirm the detected installer version and local version
- If versions match (or installer is not newer), the script will exit without changes

### Install fails
Check:
- Installer exit code in the log
- Verify the silent install flags match the installer you are using
- Ensure `pritunl.exe` is not being locked by another process (the script attempts to stop `pritunl` first)

---

## License

MIT License. See `LICENSE`.
