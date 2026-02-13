<#
.SYNOPSIS
   Pritunl Client Deployment Script (Auto-Updating) - GPO Startup Compatible
   - Compares installer EXE version on a network share to the locally installed Pritunl EXE version.
   - If newer, installs/updates silently.
   - If not installed, performs a clean install.
   - PowerShell 5.1 compatible.
#>

$AppName = "Pritunl Client"

# UNC path to installer EXE (edit this)
# Example: \\fileserver\software\Pritunl\Pritunl_Setup.exe
$InstallerPath = "[add your network path pointing to the installer file here]"

# Pritunl possible install paths (covers both 64-bit and 32-bit locations)
$PritunlExePaths = @(
    "C:\Program Files\Pritunl\pritunl.exe",
    "C:\Program Files (x86)\Pritunl\pritunl.exe"
)

$InstallArgs = "/VERYSILENT /NORESTART"

$RetryCount = 5
$RetryDelay = 10

# Logging (ProgramData)
$LogDir  = Join-Path $env:ProgramData "Pritunl\Logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir "Pritunl_Install.log"

function Write-Log {
    param([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMsg = "$TimeStamp - $Message"
    $LogMsg | Out-File -FilePath $LogFile -Append -Encoding utf8
    Write-Host $LogMsg
}

# Marker to prove script started
Set-Content -Path (Join-Path $LogDir "Pritunl_STARTED.txt") -Value (Get-Date) -Force

Write-Log "--- Starting $AppName Deployment ---"
Write-Log "InstallerPath: $InstallerPath"

# 1) Network/share readiness
$retry = 0
while (-not (Test-Path $InstallerPath) -and $retry -lt $RetryCount) {
    Write-Log "Waiting for network path ($InstallerPath)... Attempt $($retry+1) of $RetryCount"
    Start-Sleep -Seconds $RetryDelay
    $retry++
}

if (-not (Test-Path $InstallerPath)) {
    Write-Log "CRITICAL: Installer not found after retries. Aborting."
    exit 1
}

# 2) Get source version (installer on share)
try {
    $SourceVersion = ((Get-Item $InstallerPath).VersionInfo.FileVersion).Trim()
    Write-Log "Installer Version (share): $SourceVersion"
} catch {
    Write-Log "WARNING: Could not read installer version. Defaulting to 0.0.0.0"
    $SourceVersion = "0.0.0.0"
}

# 3) Find local pritunl.exe
$LocalPath = $PritunlExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($LocalPath) {
    Write-Log "Local EXE Path: $LocalPath"
} else {
    Write-Log "Local EXE Path: (not found)"
}

$NeedInstall = $false

# 4) Check local version / decide install
if ($LocalPath) {
    try {
        $LocalVersion = ((Get-Item $LocalPath).VersionInfo.FileVersion).Trim()
    } catch {
        $LocalVersion = "0.0.0.0"
    }

    Write-Log "Local Version:            $LocalVersion"

    try { $sv = [version]$SourceVersion } catch { $sv = [version]"0.0.0.0" }
    try { $lv = [version]$LocalVersion  } catch { $lv = [version]"0.0.0.0" }

    if ($sv -gt $lv) {
        Write-Log "ACTION: Update found ($sv > $lv). Installing..."
        $NeedInstall = $true
    } else {
        Write-Log "ACTION: System is up to date. Exiting."
        exit 0
    }
} else {
    Write-Log "ACTION: Clean Install ($SourceVersion). Installing..."
    $NeedInstall = $true
}

# 5) Install / Update
if ($NeedInstall) {
    try {
        # Stop running Pritunl client process before install/update
        Get-Process "pritunl" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

        Write-Log "Launching Installer..."
        $start = Get-Date
        $Process = Start-Process -FilePath $InstallerPath -ArgumentList $InstallArgs -Wait -PassThru -NoNewWindow
        $elapsed = (Get-Date) - $start

        if ($Process.ExitCode -eq 0) {
            Write-Log "SUCCESS: Installation completed. (Elapsed: $($elapsed.ToString()))"
            exit 0
        } else {
            Write-Log "ERROR: Installer failed with Exit Code: $($Process.ExitCode) (Elapsed: $($elapsed.ToString()))"
            exit $Process.ExitCode
        }
    } catch {
        Write-Log "CRITICAL ERROR: $($_.Exception.Message)"
        exit 1
    }
}

Write-Log "--- End of Script ---"
exit 0
