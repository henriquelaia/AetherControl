param(
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/henriquelaia/AetherControl"
$ZipUrl  = "https://github.com/henriquelaia/AetherControl/archive/refs/heads/main.zip"
$BaseDir = Join-Path $env:LOCALAPPDATA "AetherControl"
$InstallDir = Join-Path $BaseDir "app"

if (-not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
}

Write-Host ""
Write-Host "  AetherControl — One-Line Installer" -ForegroundColor Cyan
Write-Host "  Target Directory: $InstallDir" -ForegroundColor Gray
Write-Host ""

if (Get-Command git -ErrorAction SilentlyContinue) {
    if (Test-Path (Join-Path $InstallDir ".git")) {
        Write-Host "  Updating existing installation via Git..." -ForegroundColor Yellow
        Push-Location $InstallDir
        git pull --ff-only | Out-Null
        Pop-Location
    } else {
        if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
        Write-Host "  Cloning repository from $RepoUrl..." -ForegroundColor Yellow
        git clone --depth 1 "$RepoUrl.git" $InstallDir | Out-Null
    }
} else {
    Write-Host "  Downloading latest release archive..." -ForegroundColor Yellow
    $tmpZip = Join-Path $env:TEMP "AetherControl-main.zip"
    $tmpExtract = Join-Path $env:TEMP "AetherControl-extract"
    Invoke-WebRequest -Uri $ZipUrl -OutFile $tmpZip -UseBasicParsing
    if (Test-Path $tmpExtract) { Remove-Item $tmpExtract -Recurse -Force }
    Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
    $innerFolder = Get-ChildItem -Path $tmpExtract -Directory | Select-Object -First 1
    Move-Item -Path $innerFolder.FullName -Destination $InstallDir -Force
    Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue
}

$InstallerScript = Join-Path $InstallDir "Install-AetherControl.ps1"
if ($NoLaunch) {
    & $InstallerScript -NoLaunch
} else {
    & $InstallerScript
}
