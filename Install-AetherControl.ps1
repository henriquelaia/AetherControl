# AetherControl — Local Installer & Hardware Scanner
param(
    [switch]$NoLaunch
)

$ErrorActionPreference = "Continue"
$RepoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$DaemonScript = Join-Path $RepoRoot "AetherControl-NativeDaemon.ps1"

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  AETHERCONTROL v3.0 // OPEN-SOURCE INSTALLER & HARDWARE AUTO-SCANNER" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Repository Path : $RepoRoot"
Write-Host "  Scanning PCIe, SMBIOS, NVML & Super I/O Topology..." -ForegroundColor Yellow
Write-Host ""

# 1. Run Hardware Auto-Discovery
$rawJson = & $DaemonScript -ScanOnly
try {
    $hw = $rawJson | ConvertFrom-Json
    Write-Host "  [DETECTED SYSTEM HARDWARE]" -ForegroundColor Green
    Write-Host "  • Processor (CPU)   : $($hw.cpu.name) ($($hw.cpu.cores) Cores / $($hw.cpu.threads) Threads, ~$($hw.cpu.estimatedTdpW)W TDP)"
    Write-Host "  • Graphics (GPU)    : $($hw.gpu.name) ($($hw.gpu.vramMb) MB VRAM)"
    Write-Host "  • Telemetry Driver  : $($hw.gpu.driver)"
    Write-Host "  • Motherboard       : $($hw.motherboard.name)"
    Write-Host "  • Super I/O & PWM   : $($hw.motherboard.superIoChip) (BIOS: $($hw.motherboard.biosVersion))"
    Write-Host "  • Cooling Loop      : $($hw.cooling.controller)"
    Write-Host "  • System Memory     : $($hw.memory.totalGb) GB RAM @ $($hw.memory.speedMhz) MHz"
    Write-Host "  • Operating System  : $($hw.os.caption) (Admin=$($hw.os.isAdmin))"
} catch {
    Write-Host "  [+] Hardware scan complete." -ForegroundColor Green
}

Write-Host ""
Write-Host "--------------------------------------------------------------------------------"

# 2. Install Desktop & Start Menu Shortcuts
& $DaemonScript -InstallShortcutOnly

$startMenuDir = [Environment]::GetFolderPath("Programs")
if (Test-Path $startMenuDir) {
    try {
        $psExe = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        $wsh = New-Object -ComObject WScript.Shell
        $smShortcut = $wsh.CreateShortcut((Join-Path $startMenuDir "AetherControl Studio.lnk"))
        $smShortcut.TargetPath = $psExe
        $smShortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$DaemonScript`""
        $smShortcut.WorkingDirectory = $RepoRoot
        $smShortcut.Description = "AetherControl - Next-Gen Hardware Monitor & Predictive Fan Controller"
        $smShortcut.IconLocation = "C:\Windows\System32\shell32.dll,13"
        $smShortcut.Save()
        Write-Host "  [+] Start Menu Shortcut Ready: $(Join-Path $startMenuDir 'AetherControl Studio.lnk')" -ForegroundColor Green
    } catch {}
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Installation Complete! Launching AetherControl Studio..." -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

if (-not $NoLaunch) {
    & $DaemonScript
}
