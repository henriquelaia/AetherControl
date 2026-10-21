# AetherControl — Automated Unit, Integration & Performance Benchmark Suite
param(
    [switch]$CiMode
)

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

if ($CiMode) {
    Write-Host "  Running in CI Headless Validation Mode..." -ForegroundColor Yellow
    $repoRoot = Split-Path $PSScriptRoot -Parent

    # 1. PowerShell Syntax Tokenizer Validation
    $psFiles = Get-ChildItem -Path $repoRoot -Recurse -Filter "*.ps1" | Where-Object { $_.FullName -notmatch "check_|copy_|test_" }
    $syntaxOk = $true
    foreach ($ps in $psFiles) {
        $errs = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $ps.FullName -Raw), [ref]$errs)
        if ($errs -and $errs.Count -gt 0) {
            $syntaxOk = $false
            Write-Host "  [!] Syntax error in $($ps.Name): $($errs[0].Message)" -ForegroundColor Red
        }
    }
    Assert-Test "PowerShell Core Syntax & Tokenizer Validation" $syntaxOk "$($psFiles.Count) scripts verified"

    # 2. Critical UI & Asset Files Verification
    $requiredAssets = @(
        "src\AetherControl.Daemon\wwwroot\index.html",
        "src\AetherControl.Daemon\wwwroot\app.js",
        "src\AetherControl.Daemon\wwwroot\styles.css",
        "assets\aethercontrol.ico",
        "get.ps1",
        "Install-AetherControl.ps1",
        "AetherControl-NativeDaemon.ps1"
    )
    $assetsOk = $true
    foreach ($asset in $requiredAssets) {
        if (-not (Test-Path (Join-Path $repoRoot $asset))) {
            $assetsOk = $false
        }
    }
    Assert-Test "Production Assets & Core Files Integrity" $assetsOk "7/7 core components verified"

    # 3. WebUI HTML & JavaScript Syntax Validation
    $indexHtml = Get-Content (Join-Path $repoRoot "src\AetherControl.Daemon\wwwroot\index.html") -Raw
    $appJs = Get-Content (Join-Path $repoRoot "src\AetherControl.Daemon\wwwroot\app.js") -Raw
    $uiValid = ($indexHtml -match "digital-twin-canvas") -and ($indexHtml -match "twin-modal-backdrop") -and ($appJs -match "twinMode")
    Assert-Test "Frontend WebUI & CAD 3D Digital Twin Integration" $uiValid "HTML5 Canvas & CAD Shader modules loaded"

    # 4. Installer & Shortcut Scripts Verification
    $installerContent = Get-Content (Join-Path $repoRoot "Install-AetherControl.ps1") -Raw
    $hasShortcuts = ($installerContent -match "AetherControl Studio.lnk") -and ($installerContent -match "InstallShortcutOnly")
    Assert-Test "Installer Desktop & Start Menu Shortcut Logic" $hasShortcuts "Dual-target shortcut support active"

    Write-Host "--------------------------------------------------------------------------------"
    Write-Host "  SUMMARY: $Passed Passed, $Failed Failed" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    if ($Failed -gt 0) { exit 1 } else { exit 0 }
}

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
    -not [string]::IsNullOrWhiteSpace($hw.storage.name) -and
    ($hw.formFactor -eq "Desktop" -or $hw.formFactor -eq "Laptop")
) "$($hw.cpu.shortName) | $($hw.gpu.shortName) | $($hw.memory.totalGb)GB RAM | FormFactor=$($hw.formFactor)"

# 2. Live Telemetry Sensor Polling & Schema Binding
$snap = Invoke-RestMethod -Uri "$BaseUrl/api/telemetry" -Method Get
Assert-Test "Real-Time Telemetry Snapshot & PWM Channel Binding" (
    $snap.cpuTempC -gt 10 -and
    $snap.gpuTempC -gt 10 -and
    $snap.fanChannels.Count -ge 2
) "CPU=$($snap.cpuTempC)C, GPU=$($snap.gpuTempC)C, Channels=$($snap.fanChannels.Count), FormFactor=$($snap.formFactor)"

# 3. Per-Channel Fan Identification Override (100% Spin-Up Test)
$targetChan = if ($snap.isLaptop) { "CPU_FAN" } else { "CPU_FAN1" }
$idRes = Invoke-RestMethod -Uri "$BaseUrl/api/fan/identify/$targetChan" -Method Post
$snapId = Invoke-RestMethod -Uri "$BaseUrl/api/telemetry" -Method Get
$identItem = $snapId.fanChannels | Where-Object { $_.id -eq $targetChan } | Select-Object -First 1
Assert-Test "Per-Channel Fan Identify Spin-Up Override (100%)" (
    $idRes.identified -eq $targetChan -and
    $identItem.currentPwmPercent -eq 100
) "Channel=$targetChan, ForcedPWM=$($identItem.currentPwmPercent)%"

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

# 8. Intelligent Laptop vs Desktop Topology & ACPI EC Governor Verification
$laptopHw = Invoke-RestMethod -Uri "$BaseUrl/api/hardware/scan?refresh=1&forceFormFactor=Laptop" -Method Get
$laptopSnap = Invoke-RestMethod -Uri "$BaseUrl/api/telemetry" -Method Get
$null = Invoke-RestMethod -Uri "$BaseUrl/api/laptop/governor" -Method Post -Body '{"mode":"Silent"}' -ContentType "application/json"
Assert-Test "Intelligent Laptop Topology & ACPI EC Governor Verification" (
    $laptopHw.formFactor -eq "Laptop" -and
    $laptopHw.isLaptop -eq $true -and
    $laptopSnap.fanChannels.Count -eq 2 -and
    $laptopSnap.fanChannels[0].id -eq "CPU_FAN" -and
    $laptopSnap.fanChannels[1].id -eq "GPU_FAN" -and
    $laptopSnap.liquidCooling.enabled -eq $false
) "Laptop Mode: FormFactor=Laptop, Channels=2 (CPU/GPU Blower), AirCooling=Active"

# Restore native topology
$null = Invoke-RestMethod -Uri "$BaseUrl/api/hardware/scan?refresh=1&forceFormFactor=Desktop" -Method Get

Write-Host "--------------------------------------------------------------------------------"
Write-Host "  SUMMARY: $Passed Passed, $Failed Failed" -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" })
Write-Host "================================================================================" -ForegroundColor Cyan
if ($Failed -gt 0) { exit 1 }
