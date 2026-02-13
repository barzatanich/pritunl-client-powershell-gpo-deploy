<#
.SYNOPSIS
   Application Deployment Script (Auto-Updating) - GPO Startup Compatible
   - Compares installer EXE version on a network share to the locally installed EXE version.
   - If newer, installs/updates silently.
   - If not installed, performs a clean install.
   - PowerShell 5.1 compatible.
#>

# -----------------------------
# Customize these values
# -----------------------------
$AppName = "Pritunl Client"

# Network path to the installer EXE (UNC path recommended for GPO Startup scripts)
# Example: \\fileserver\software\Pritunl\Pritunl_Setup.exe
$InstallerPath = "[add your network path pointing to the installer file here]"

# Path to the locally installed EXE used for version comparison
# Example: C:\Program Files (x86)\Pritunl\pritunl.exe
$LocalPath = "[add your local exe path here]"

# Silent install arguments for the installer
$InstallArgs = "/VERYSILENT /NORESTART"

# Network readiness retry (helps during boot when network is not immediately ready)
$RetryCount = 5
$RetryDelay = 10

# Logging (ProgramData)
$LogRoot = "OrgName"   # change this to your org/app grouping, e.g., "Company", "IT", "Deployment"
$LogDir  = Join-Path $env:ProgramData "$LogRoot\Logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir "App_Install.log"

function Write-Log {
    param([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMsg = "$TimeStamp - $Message"
    $LogMsg | Out-File -FilePath $LogFile -Append -Encoding utf8
    Write-Host $LogMsg
}

# Marker to prove script started
Set-Content -Path (Join-Path $LogDir "STARTED.txt") -Value (Get-Date) -Force

Write-Log "--- Starting $AppName Deployment ---"
Write-Log "InstallerPath: $InstallerPath"
Write-Log "LocalPath:     $LocalPath"

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

# 2) Get source (installer) version
try {
    $SourceVersion = ((Get-Item $InstallerPath).VersionInfo.FileVersion).Trim()
    Write-Log "Server/Share Version: $SourceVersion"
} catch {
    Write-Log "WARNING: Could not read installer version. Defaulting to 0.0.0.0"
    $SourceVersion = "0.0.0.0"
}

$NeedInstall = $false

# 3) Check local version / decide install
if (Test-Path $LocalPath) {
    try {
        $LocalVersion = ((Get-Item $LocalPath).VersionInfo.FileVersion).Trim()
    } catch {
        $LocalVersion = "0.0.0.0"
    }

    Write-Log "Local Version:        $LocalVersion"

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

# 4) Install
if ($NeedInstall) {
    try {
        # Stop app process if it exists (optional; adjust for your app)
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
