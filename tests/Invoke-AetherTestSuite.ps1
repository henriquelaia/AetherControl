# AetherControl — Automated Unit, Integration & Performance Benchmark Suite
$ErrorActionPreference = "Stop"
$BaseUrl = "http://127.0.0.1:5175"
$Passed = 0
$Failed = 0

function Assert-Test([string]$Name, [bool]$Condition, [string]$Details = "") {
    if ($Condition) {
        $Script:Passed++
        Write-Host "  [PASS] $Name $(if ($Details) { "($Details)" })" -ForegroundColor Green
    } else {
        $Script:Failed++
        Write-Host "  [FAIL] $Name $(if ($Details) { "($Details)" })" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  AETHERCONTROL // AUTOMATED UNIT, INTEGRATION & MEMORY BENCHMARK SUITE" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

$daemonReady = $false
try {
    $null = Invoke-RestMethod -Uri "$BaseUrl/api/telemetry" -TimeoutSec 1 -ErrorAction Stop
    $daemonReady = $true
} catch {
    $daemonScript = Join-Path (Split-Path $PSScriptRoot -Parent) "AetherControl-NativeDaemon.ps1"
    Start-Process -FilePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$daemonScript`" -NoBrowser" | Out-Null
    for ($retry = 0; $retry -lt 20; $retry++) {
        Start-Sleep -Milliseconds 400
        try {
            $null = Invoke-RestMethod -Uri "$BaseUrl/api/telemetry" -TimeoutSec 1 -ErrorAction Stop
            $daemonReady = $true
            break
        } catch {}
    }
}

# 1. Hardware Auto-Discovery Test
$hw = Invoke-RestMethod -Uri "$BaseUrl/api/hardware/scan?refresh=1" -Method Get
Assert-Test "Hardware Auto-Scanner (CPU/GPU/RAM/Storage/SuperIO)" (
    -not [string]::IsNullOrWhiteSpace($hw.cpu.name) -and
    -not [string]::IsNullOrWhiteSpace($hw.gpu.name) -and
    $hw.memory.totalGb -ge 1 -and
    -not [string]::IsNullOrWhiteSpace($hw.storage.name)
) "$($hw.cpu.shortName) | $($hw.gpu.shortName) | $($hw.memory.totalGb)GB RAM | $($hw.storage.name)"

# 2. Live Telemetry Sensor Polling & Schema Binding
$snap = Invoke-RestMethod -Uri "$BaseUrl/api/telemetry" -Method Get
Assert-Test "Real-Time Telemetry Snapshot & 4-Channel PWM Binding" (
    $snap.cpuTempC -gt 10 -and
    $snap.gpuTempC -gt 10 -and
    $snap.liquidCooling.coolantTempC -gt 15 -and
    $snap.fanChannels.Count -ge 4
) "CPU=$($snap.cpuTempC)C, GPU=$($snap.gpuTempC)C, Coolant=$($snap.liquidCooling.coolantTempC)C"

# 3. Per-Channel Fan Identification Override (100% Spin-Up Test)
$idRes = Invoke-RestMethod -Uri "$BaseUrl/api/fan/identify/CPU_FAN1" -Method Post
$snapId = Invoke-RestMethod -Uri "$BaseUrl/api/telemetry" -Method Get
Assert-Test "Per-Channel Fan Identify Spin-Up Override (100%)" (
    $idRes.identified -eq "CPU_FAN1" -and
    $snapId.fanChannels[1].currentPwmPercent -eq 100
) "Channel=CPU_FAN1, ForcedPWM=$($snapId.fanChannels[1].currentPwmPercent)%"

# 4. Community Profiles Catalog & 1-Click Application
$profiles = Invoke-RestMethod -Uri "$BaseUrl/api/community/profiles" -Method Get
Assert-Test "Community Profiles Catalog Loaded" ($profiles.Count -ge 4) "$($profiles.Count) curated profiles"

$applyRes = Invoke-RestMethod -Uri "$BaseUrl/api/community/profiles/apply/aio-360-liquid-equilibrium" -Method Post
Assert-Test "Community Profile 1-Click Apply & Coolant Sync" (
    $applyRes.applied -eq "HydroLoop 360mm Equilibrium" -and
    $applyRes.fanConfig.temperatureSource -eq "LIQUID_COOLANT"
) "Applied=$($applyRes.applied)"

# Restore Balanced preset after test
$null = Invoke-RestMethod -Uri "$BaseUrl/api/fan/preset/Balanced" -Method Post

# 5. Modular Plugin API State Toggling
$pluginsBefore = Invoke-RestMethod -Uri "$BaseUrl/api/plugins" -Method Get
$csvInitial = ($pluginsBefore | Where-Object { $_.id -eq "csv-flight-recorder" }).enabled
$pluginsAfter = Invoke-RestMethod -Uri "$BaseUrl/api/plugins/toggle/csv-flight-recorder" -Method Post
$csvToggled = ($pluginsAfter | Where-Object { $_.id -eq "csv-flight-recorder" }).enabled
Assert-Test "Modular Plugin API Toggle State" ($csvInitial -ne $csvToggled) "csv-flight-recorder: $csvInitial -> $csvToggled"
# Restore initial plugin state
$null = Invoke-RestMethod -Uri "$BaseUrl/api/plugins/toggle/csv-flight-recorder" -Method Post

# 6. Profile Export & Persistence Validation
$exported = Invoke-RestMethod -Uri "$BaseUrl/api/profile/export" -Method Get
Assert-Test "Settings Persistence & JSON Profile Export" (
    $null -ne $exported.fanConfig -and
    $exported.fanConfig.curvePoints.Count -ge 4
) "Preset=$($exported.fanConfig.activePreset), Points=$($exported.fanConfig.curvePoints.Count)"

# 7. High-Frequency Polling Latency & Memory Leak Benchmark (40 rapid cycles)
for ($w = 0; $w -lt 5; $w++) { $null = Invoke-RestMethod -Uri "$BaseUrl/api/telemetry" -Method Get }
$warmSnap = Invoke-RestMethod -Uri "$BaseUrl/api/telemetry" -Method Get
$ramStart = [double]$warmSnap.daemonRamMb
$sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt 40; $i++) {
    $s = Invoke-RestMethod -Uri "$BaseUrl/api/telemetry" -Method Get
}
$sw.Stop()
$ramEnd = [double]$s.daemonRamMb
$avgMs = [math]::Round($sw.Elapsed.TotalMilliseconds / 40.0, 2)
$ramDelta = [math]::Round($ramEnd - $ramStart, 1)

Assert-Test "Telemetry Polling Latency & Zero Memory Leak Benchmark" (
    $avgMs -lt 25.0 -and [math]::Abs($ramDelta) -le 2.5
) "AvgLatency=${avgMs}ms/req, StartRAM=${ramStart}MB, EndRAM=${ramEnd}MB, Delta=${ramDelta}MB"

Write-Host "--------------------------------------------------------------------------------"
Write-Host "  SUMMARY: $Passed Passed, $Failed Failed" -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" })
Write-Host "================================================================================" -ForegroundColor Cyan
if ($Failed -gt 0) { exit 1 }
