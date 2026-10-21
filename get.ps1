# AetherControl - Universal One-Line Installer
[CmdletBinding()]
param(
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

# Enable TLS 1.2 and TLS 1.3 for legacy Windows PowerShell
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {}

# Set process execution policy to bypass to ensure scripts run
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
} catch {}

$RepoUrl = "https://github.com/henriquelaia/AetherControl"
$ZipUrl  = "https://github.com/henriquelaia/AetherControl/archive/refs/heads/main.zip"
$BaseDir = Join-Path $env:LOCALAPPDATA "AetherControl"
$InstallDir = Join-Path $BaseDir "app"

if (-not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  AETHERCONTROL // UNIVERSAL INSTALLER" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Destination: $InstallDir" -ForegroundColor Gray
Write-Host ""

$hasGit = $false
try {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $hasGit = $true
    }
} catch {}

if ($hasGit) {
    if (Test-Path (Join-Path $InstallDir ".git")) {
        Write-Host "  [*] Updating existing installation via Git..." -ForegroundColor Yellow
        Push-Location $InstallDir
        git pull --ff-only | Out-Null
        Pop-Location
    } else {
        if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
        Write-Host "  [*] Cloning repository from $RepoUrl..." -ForegroundColor Yellow
        git clone --depth 1 "$RepoUrl.git" $InstallDir | Out-Null
    }
} else {
    Write-Host "  [*] Downloading latest release from GitHub..." -ForegroundColor Yellow
    $tmpZip = Join-Path $env:TEMP "AetherControl-main.zip"
    $tmpExtract = Join-Path $env:TEMP "AetherControl-extract"

    if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tmpExtract) { Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue }

    Invoke-WebRequest -Uri $ZipUrl -OutFile $tmpZip -UseBasicParsing
    Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force

    $innerFolder = Get-ChildItem -Path $tmpExtract -Directory | Select-Object -First 1

    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    Copy-Item -Path "$($innerFolder.FullName)\*" -Destination $InstallDir -Recurse -Force

    Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue
}

$InstallerScript = Join-Path $InstallDir "Install-AetherControl.ps1"
$psExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $psExe)) { $psExe = "powershell.exe" }

if (Test-Path $InstallerScript) {
    Write-Host "  [+] Installation files deployed successfully." -ForegroundColor Green
    if ($NoLaunch) {
        & $psExe -NoProfile -ExecutionPolicy Bypass -File "$InstallerScript" -NoLaunch
    } else {
        & $psExe -NoProfile -ExecutionPolicy Bypass -File "$InstallerScript"
    }
} else {
    Write-Host "  [!] Error: Installer script was not found at $InstallerScript" -ForegroundColor Red
    exit 1
}
