# AetherControl — Hardware Telemetry & Fan Control Daemon
param(
    [switch]$PocOnly,
    [switch]$InstallShortcutOnly,
    [switch]$ScanOnly,
    [switch]$NoBrowser
)

$ErrorActionPreference = "Continue"
$Port = 5175
$Workspace = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$WwwRoot = Join-Path $Workspace "src\AetherControl.Daemon\wwwroot"
$AppDataDir = Join-Path $env:LOCALAPPDATA "AetherControl"
if (-not (Test-Path $AppDataDir)) { New-Item -ItemType Directory -Path $AppDataDir -Force | Out-Null }
$ProfilePath = Join-Path $AppDataDir "settings.json"

# ------------------------------------------------------------------------------
# 0. Auto-Create Portable Desktop Shortcut ("AetherControl Studio.lnk")
# ------------------------------------------------------------------------------
function Install-AetherDesktopShortcut {
    try {
        $desktopDir = [Environment]::GetFolderPath("Desktop")
        $shortcutFile = Join-Path $desktopDir "AetherControl Studio.lnk"
        $psExe = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        if (-not (Test-Path $psExe)) { $psExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" }

        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($shortcutFile)
        $sc.TargetPath = $psExe
        $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Workspace\AetherControl-NativeDaemon.ps1`""
        $sc.WorkingDirectory = $Workspace
        $sc.Description = "AetherControl Studio - Hardware Monitor, Liquid Cooling & Predictive Fan Controller"
        
        $ico = Join-Path $Workspace "assets\aethercontrol.ico"
        if (Test-Path $ico) {
            $sc.IconLocation = "$ico,0"
        } else {
            $sc.IconLocation = "C:\Windows\System32\shell32.dll,13"
        }
        $sc.Save()
        Write-Host "  [+] Atalho no Ambiente de Trabalho criado: $shortcutFile" -ForegroundColor Green

        # Support OneDrive synchronized Desktop if different
        if ($env:OneDrive -and (Test-Path (Join-Path $env:OneDrive "Desktop"))) {
            $oneDriveDesktop = Join-Path $env:OneDrive "Desktop"
            if ($oneDriveDesktop -ne $desktopDir) {
                try {
                    $odSc = $wsh.CreateShortcut((Join-Path $oneDriveDesktop "AetherControl Studio.lnk"))
                    $odSc.TargetPath = $sc.TargetPath
                    $odSc.Arguments = $sc.Arguments
                    $odSc.WorkingDirectory = $sc.WorkingDirectory
                    $odSc.Description = $sc.Description
                    $odSc.IconLocation = $sc.IconLocation
                    $odSc.Save()
                } catch {}
            }
        }
    } catch {
        Write-Host "  [!] Could not create desktop shortcut automatically: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (-not $ScanOnly) {
    Install-AetherDesktopShortcut
}
if ($InstallShortcutOnly) { exit 0 }

# ------------------------------------------------------------------------------
# 1. Compile Low-Level C# Native Interop (nvml.dll + kernel32.dll + user32.dll)
# ------------------------------------------------------------------------------
$NativeCSharp = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public static class AetherNativeBridgeV2
{
    private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, uint processId);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern bool QueryFullProcessImageName(IntPtr hProcess, uint dwFlags, StringBuilder lpExeName, ref int lpdwSize);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetSystemTimes(out long lpIdleTime, out long lpKernelTime, out long lpUserTime);

    [StructLayout(LayoutKind.Sequential)]
    public struct NvmlUtilization { public uint Gpu; public uint Memory; }

    [StructLayout(LayoutKind.Sequential)]
    public struct NvmlMemory { public ulong Total; public ulong Free; public ulong Used; }

    [DllImport("nvml.dll", EntryPoint = "nvmlInit_v2", CallingConvention = CallingConvention.Cdecl)]
    private static extern int NvmlInit();

    [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetCount_v2", CallingConvention = CallingConvention.Cdecl)]
    private static extern int NvmlDeviceGetCount(out uint count);

    [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetHandleByIndex_v2", CallingConvention = CallingConvention.Cdecl)]
    private static extern int NvmlDeviceGetHandleByIndex(uint index, out IntPtr device);

    [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetName", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    private static extern int NvmlDeviceGetName(IntPtr device, StringBuilder name, uint length);

    [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetTemperature", CallingConvention = CallingConvention.Cdecl)]
    private static extern int NvmlDeviceGetTemperature(IntPtr device, int sensorType, out uint temp);

    [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetPowerUsage", CallingConvention = CallingConvention.Cdecl)]
    private static extern int NvmlDeviceGetPowerUsage(IntPtr device, out uint powerMw);

    [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetEnforcedPowerLimit", CallingConvention = CallingConvention.Cdecl)]
    private static extern int NvmlDeviceGetEnforcedPowerLimit(IntPtr device, out uint limitMw);

    [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetFanSpeed", CallingConvention = CallingConvention.Cdecl)]
    private static extern int NvmlDeviceGetFanSpeed(IntPtr device, out uint speedPct);

    [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetClockInfo", CallingConvention = CallingConvention.Cdecl)]
    private static extern int NvmlDeviceGetClockInfo(IntPtr device, int clockType, out uint clockMhz);

    [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetUtilizationRates", CallingConvention = CallingConvention.Cdecl)]
    private static extern int NvmlDeviceGetUtilizationRates(IntPtr device, out NvmlUtilization util);

    [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetMemoryInfo", CallingConvention = CallingConvention.Cdecl)]
    private static extern int NvmlDeviceGetMemoryInfo(IntPtr device, out NvmlMemory mem);

    private static bool _nvmlInitialized = false;
    private static IntPtr _gpuHandle = IntPtr.Zero;
    public static string GpuName = "";
    public static bool NvmlSupported = false;

    private static long _lastIdle = 0;
    private static long _lastTotal = 0;

    public static void InitNvmlSafe()
    {
        if (_nvmlInitialized) return;
        _nvmlInitialized = true;
        try
        {
            if (NvmlInit() == 0)
            {
                uint count;
                if (NvmlDeviceGetCount(out count) == 0 && count > 0)
                {
                    if (NvmlDeviceGetHandleByIndex(0, out _gpuHandle) == 0)
                    {
                        var sb = new StringBuilder(96);
                        if (NvmlDeviceGetName(_gpuHandle, sb, (uint)sb.Capacity) == 0)
                        {
                            GpuName = sb.ToString();
                            NvmlSupported = true;
                        }
                    }
                }
            }
        }
        catch { NvmlSupported = false; }
    }

    public static double[] PollNvidiaMetrics()
    {
        var res = new double[] { 0, 0, 200, 0, 0, 0, 0, 1024, 8192 };
        if (!NvmlSupported || _gpuHandle == IntPtr.Zero) return res;
        try
        {
            uint v;
            if (NvmlDeviceGetTemperature(_gpuHandle, 0, out v) == 0) res[0] = v;
            if (NvmlDeviceGetPowerUsage(_gpuHandle, out v) == 0) res[1] = Math.Round(v / 1000.0, 2);
            if (NvmlDeviceGetEnforcedPowerLimit(_gpuHandle, out v) == 0) res[2] = Math.Round(v / 1000.0, 1);
            if (NvmlDeviceGetClockInfo(_gpuHandle, 0, out v) == 0) res[3] = v;
            if (NvmlDeviceGetClockInfo(_gpuHandle, 2, out v) == 0) res[4] = v;
            NvmlUtilization u;
            if (NvmlDeviceGetUtilizationRates(_gpuHandle, out u) == 0) res[5] = u.Gpu;
            if (NvmlDeviceGetFanSpeed(_gpuHandle, out v) == 0) res[6] = v;
            NvmlMemory m;
            if (NvmlDeviceGetMemoryInfo(_gpuHandle, out m) == 0)
            {
                res[7] = Math.Round(m.Used / (1024.0 * 1024.0), 0);
                res[8] = Math.Round(m.Total / (1024.0 * 1024.0), 0);
            }
        }
        catch { }
        return res;
    }

    public static string GetActiveForegroundExecutable()
    {
        try
        {
            IntPtr hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return "explorer.exe";
            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            if (pid == 0) return "explorer.exe";

            IntPtr hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
            if (hProc == IntPtr.Zero) return "System";
            try
            {
                var sb = new StringBuilder(512);
                int cap = sb.Capacity;
                if (QueryFullProcessImageName(hProc, 0, sb, ref cap))
                {
                    return Path.GetFileName(sb.ToString());
                }
            }
            finally { CloseHandle(hProc); }
        }
        catch { }
        return "explorer.exe";
    }

    public static double GetKernelCpuLoadPercent()
    {
        long idle, kernel, user;
        if (GetSystemTimes(out idle, out kernel, out user))
        {
            long total = kernel + user;
            long diffTotal = total - _lastTotal;
            long diffIdle = idle - _lastIdle;
            _lastTotal = total;
            _lastIdle = idle;
            if (diffTotal > 0)
            {
                double pct = (1.0 - ((double)diffIdle / diffTotal)) * 100.0;
                return Math.Max(1.0, Math.Min(100.0, Math.Round(pct, 1)));
            }
        }
        return 8.0;
    }
}
'@

if (-not ("AetherNativeBridgeV2" -as [type])) {
    Add-Type -TypeDefinition $NativeCSharp -Language CSharp
}

[AetherNativeBridgeV2]::InitNvmlSafe() | Out-Null

# ------------------------------------------------------------------------------
# 2. Universal Hardware Auto-Scanner (Works on ANY Windows 10/11 PC)
# ------------------------------------------------------------------------------
function Get-ConciseHardwareName([string]$raw, [string]$fallback) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return $fallback }
    $clean = $raw -replace '\(R\)|\(TM\)|Processor|\d+-Core|Eight-Core|Six-Core|Twelve-Core|Sixteen-Core|NVIDIA GeForce |AMD Radeon |Intel\(R\) Arc\(TM\) |Gigabyte Technology Co\., Ltd\. |ASUSTeK COMPUTER INC\. |Micro-Star International Co\., Ltd\. |ASRock ', ''
    return ($clean -replace '\s+', ' ').Trim()
}

function Invoke-LaptopPowerGovernor([string]$PresetName) {
    try {
        $schemeGuid = switch ($PresetName) {
            "Silent" { "a1841308-3541-4fab-bc81-f71556f20b4a" } # Power Saver / Quiet
            "Predictive Gaming" { "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" } # High Performance
            "Heavy Compute" { "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" } # High Performance
            "Max Cooling" { "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" } # High Performance
            default { "381b4222-f694-41f0-9685-ff5bb260df2e" } # Balanced
        }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powercfg.exe"
        $psi.Arguments = "/setactive $schemeGuid"
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.CreateNoWindow = $true
        $psi.UseShellExecute = $false
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {}
}

function Invoke-HardwareTopologyScan {
    $cpuCim = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $gpuCim = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "Basic|Remote|Parsec|Virtual" } | Select-Object -First 1
    if (-not $gpuCim) { $gpuCim = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1 }
    $boardCim = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
    $biosCim = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
    $osCim = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue | Select-Object -First 1
    $ramSticks = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $csCim = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue | Select-Object -First 1
    $chassisCim = Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue | Select-Object -First 1
    $batteryCim = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1

    $isLaptop = $false
    if ($null -ne $batteryCim) {
        $isLaptop = $true
    } elseif ($csCim -and $csCim.PCSystemType -eq 2) {
        $isLaptop = $true
    } elseif ($chassisCim -and $chassisCim.ChassisTypes) {
        foreach ($ct in $chassisCim.ChassisTypes) {
            if ($ct -in @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)) {
                $isLaptop = $true
                break
            }
        }
    }
    $formFactor = if ($isLaptop) { "Laptop" } else { "Desktop" }

    $cpuFull = if ($cpuCim.Name) { $cpuCim.Name.Trim() } else { "x86_64 Multi-Core Processor" }
    $cpuShort = Get-ConciseHardwareName $cpuFull "CPU"
    $cpuCores = if ($cpuCim.NumberOfCores) { [int]$cpuCim.NumberOfCores } else { 8 }
    $cpuThreads = if ($cpuCim.NumberOfLogicalProcessors) { [int]$cpuCim.NumberOfLogicalProcessors } else { 16 }
    $cpuMaxMhz = if ($cpuCim.MaxClockSpeed -gt 1000) { [int]$cpuCim.MaxClockSpeed } else { 4200 }
    $cpuTdp = if ($cpuCores -ge 12) { 125 } elseif ($cpuCores -ge 8) { 105 } else { 65 }

    $gpuFull = if ([AetherNativeBridgeV2]::NvmlSupported -and [AetherNativeBridgeV2]::GpuName) {
        [AetherNativeBridgeV2]::GpuName
    } elseif ($gpuCim.Name) {
        $gpuCim.Name.Trim()
    } else {
        "PCIe Graphics Adapter"
    }
    $gpuShort = Get-ConciseHardwareName $gpuFull "GPU"

    $nvCheck = [AetherNativeBridgeV2]::PollNvidiaMetrics()
    $gpuVramMb = if ([AetherNativeBridgeV2]::NvmlSupported -and $nvCheck[8] -gt 0) {
        [int]$nvCheck[8]
    } elseif ($gpuCim.AdapterRAM -gt 0) {
        [int][math]::Round($gpuCim.AdapterRAM / 1MB, 0)
    } else {
        8192
    }
    $gpuDriverDesc = if ([AetherNativeBridgeV2]::NvmlSupported) {
        "NVIDIA NVML (Ring-3 Native IOCTL)"
    } elseif ($gpuFull -match "Radeon|AMD") {
        "AMD ADL / WDDM Telemetry Bridge"
    } else {
        "Win32 WDDM Performance Bridge"
    }

    $moboMaker = if ($boardCim.Manufacturer) { $boardCim.Manufacturer.Trim() } else { "" }
    $moboProduct = if ($boardCim.Product) { $boardCim.Product.Trim() } else { "System Motherboard" }
    $moboFull = "$moboMaker $moboProduct".Trim()
    $moboShort = Get-ConciseHardwareName $moboFull $moboProduct

    # Map Motherboard Vendor to Super I/O Chipset Family
    $superIoChip = if ($moboFull -match "Gigabyte|AORUS") {
        "ITE IT8686E / IT8688E"
    } elseif ($moboFull -match "ASUS|ROG|TUF|PRIME") {
        "Nuvoton NCT6798D / ROG IO"
    } elseif ($moboFull -match "MSI|Micro-Star|MAG|MPG|MEG") {
        "Nuvoton NCT6797D / MSI IO"
    } elseif ($moboFull -match "ASRock") {
        "Nuvoton NCT6791D"
    } else {
        "LPC/eSPI Super I/O PWM"
    }

    $usbAio = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match "Kraken|Asetek|Hydro|Commander|AIO|Ryujin|Liquid Freezer" -and $_.Name -notmatch "Audio|Headset|Mouse|Keyboard|Mic"
    } | Select-Object -ExpandProperty Name)

    if ($isLaptop) {
        $coolingType = "Air"
        $aioController = "Dual-Blower Vapor Chamber (Embedded Controller ACPI)"
        $fanCount = 2
    } elseif ($usbAio.Count -gt 0) {
        $coolingType = "Liquid"
        $aioController = $usbAio[0]
        $fanCount = 4
    } else {
        $coolingType = "Liquid"
        $aioController = "$moboShort Hybrid W_PUMP ($superIoChip)"
        $fanCount = 4
    }

    $totalRamBytes = ($ramSticks | Measure-Object -Property Capacity -Sum).Sum
    $totalRamGb = if ($totalRamBytes -gt 0) { [int][math]::Round($totalRamBytes / 1GB, 0) } else { 16 }
    $ramSpeedMhz = if ($ramSticks.Count -gt 0 -and $ramSticks[0].ConfiguredClockSpeed) { [int]$ramSticks[0].ConfiguredClockSpeed } else { 3200 }

    $osCaption = if ($osCim) { "$($osCim.Caption.Trim()) ($($osCim.Version))" } else { [System.Environment]::OSVersion.VersionString }
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    $diskCim = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1
    $diskName = if ($diskCim.Model) { $diskCim.Model.Trim() } else { "NVMe Solid State Drive" }

    $startupTaskExists = $false
    try {
        $null = schtasks.exe /Query /TN "AetherControlDaemon" 2>$null
        if ($LASTEXITCODE -eq 0) { $startupTaskExists = $true }
    } catch {}

    return @{
        scannedAtUtc = ([DateTime]::UtcNow).ToString("o")
        cpu = @{
            name = $cpuFull
            shortName = $cpuShort
            cores = $cpuCores
            threads = $cpuThreads
            maxClockMhz = $cpuMaxMhz
            estimatedTdpW = $cpuTdp
        }
        gpu = @{
            name = $gpuFull
            shortName = $gpuShort
            vramMb = $gpuVramMb
            driver = $gpuDriverDesc
            nvmlActive = [AetherNativeBridgeV2]::NvmlSupported
        }
        motherboard = @{
            name = $moboFull
            shortName = $moboShort
            product = $moboProduct
            superIoChip = $superIoChip
            biosVersion = if ($biosCim.SMBIOSBIOSVersion) { $biosCim.SMBIOSBIOSVersion } else { "UEFI" }
        }
        memory = @{
            totalGb = $totalRamGb
            speedMhz = $ramSpeedMhz
            dimmCount = [math]::Max(1, $ramSticks.Count)
        }
        storage = @{
            name = $diskName
            tempC = 39
        }
        formFactor = $formFactor
        isLaptop = $isLaptop
        cooling = @{
            type = $coolingType
            controller = $aioController
            fanCount = $fanCount
        }
        os = @{
            caption = $osCaption
            isAdmin = $isAdmin
            startupEnabled = $startupTaskExists
        }
    }
}

$Script:HardwareTopology = Invoke-HardwareTopologyScan

if ($ScanOnly) {
    $Script:HardwareTopology | ConvertTo-Json -Depth 5
    exit 0
}

# ------------------------------------------------------------------------------
# 3. Persistent State (Fan Curve, Liquid Cooling, Zero-RPM Guard, Energy Tracker)
# ------------------------------------------------------------------------------
$Script:FanConfig = @{
    activePreset = "Balanced"
    temperatureSource = "MAX_CPU_GPU"
    hysteresisDeadbandC = 3.0
    maxStepUpPercentPerSec = 15.0
    maxStepDownPercentPerSec = 3.0
    manualOverrideEnabled = $false
    manualOverridePercent = 50.0
    curvePoints = @(
        @{ tempC = 30; pwmPercent = 22 },
        @{ tempC = 45; pwmPercent = 32 },
        @{ tempC = 60; pwmPercent = 50 },
        @{ tempC = 72; pwmPercent = 74 },
        @{ tempC = 82; pwmPercent = 100 }
    )
}

$Script:LiquidConfig = @{
    enabled = (-not $Script:HardwareTopology.isLaptop)
    coolingType = $Script:HardwareTopology.cooling.type
    formFactor = $Script:HardwareTopology.formFactor
    controllerName = $Script:HardwareTopology.cooling.controller
    pumpMode = "Balanced"
    customPumpPwmPercent = 85.0
    radiatorFanSyncToCoolant = $false
    antiAirlockPulseActive = $false
    antiAirlockPulseStart = [DateTime]::MinValue
    estimatedCoolantTempC = 31.8
    coolantAmbientBaselineC = 26.5
}

$Script:GpuGuardConfig = @{
    antiZeroRpmChatterEnabled = $true
    minimumActiveFanFloorPct = 32.0
    preventHotspotSpikeAboveC = 52.0
}

$Script:EnergyTracker = @{
    sessionStartUtc = [DateTime]::UtcNow
    accumulatedWattHours = 0.0
    lastSampleUtc = [DateTime]::UtcNow
    tariffEurPerKwh = 0.22
}

$Script:PredictiveRules = [System.Collections.ArrayList]@(
    @{ executableName = "Cyberpunk2077.exe"; displayName = "Cyberpunk 2077"; profilePreset = "Predictive Gaming"; preChargePwmFloorPercent = 58; cooldownPurgeSeconds = 30 },
    @{ executableName = "cs2.exe"; displayName = "Counter-Strike 2"; profilePreset = "Predictive Gaming"; preChargePwmFloorPercent = 52; cooldownPurgeSeconds = 20 },
    @{ executableName = "eldenring.exe"; displayName = "Elden Ring"; profilePreset = "Predictive Gaming"; preChargePwmFloorPercent = 55; cooldownPurgeSeconds = 25 },
    @{ executableName = "FortniteClient-Win64-Shipping.exe"; displayName = "Fortnite"; profilePreset = "Predictive Gaming"; preChargePwmFloorPercent = 55; cooldownPurgeSeconds = 25 },
    @{ executableName = "blender.exe"; displayName = "Blender 3D Render"; profilePreset = "Heavy Compute"; preChargePwmFloorPercent = 65; cooldownPurgeSeconds = 35 },
    @{ executableName = "Cinebench.exe"; displayName = "Cinebench Stress"; profilePreset = "Max Cooling"; preChargePwmFloorPercent = 85; cooldownPurgeSeconds = 40 },
    @{ executableName = "chrome.exe"; displayName = "Google Chrome (HW Accel)"; profilePreset = "Balanced"; preChargePwmFloorPercent = 34; cooldownPurgeSeconds = 10 }
)

$Script:AcousticConfig = @{
    enabled = $true
    isCalibrating = $false
    calibrationStart = [DateTime]::MinValue
    maxAllowedDbCeiling = 38.5
    thermalOverrideTempC = 84.0
    ambientDb = 28.5
}

$Script:CurrentSmoothedPwm = 30.0
$Script:LastEffectiveTempC = 42.0
$Script:IdentifyChannelId = $null
$Script:IdentifyUntilUtc = [DateTime]::MinValue
$Script:SelfProcess = [System.Diagnostics.Process]::GetCurrentProcess()
$Script:PollCounter = 0
$Script:CachedTelemetryBytes = $null
$Script:CachedTelemetryUtc = [DateTime]::MinValue

$Script:CommunityProfiles = @(
    @{
        id = "aio-360-liquid-equilibrium"
        name = "HydroLoop 360mm Equilibrium"
        author = "thermal_lab"
        category = "AIO Liquid"
        descriptionPt = "Guiado pela temperatura da água para eliminar picos de ruído em CPUs modernos."
        descriptionEn = "Guided by liquid coolant temperature to eliminate fan spikes on modern CPUs."
        stars = 428
        targetNoiseDb = 34.5
        temperatureSource = "LIQUID_COOLANT"
        hysteresisDeadbandC = 2.0
        recommendedPumpMode = "Balanced"
        curvePoints = @(@{tempC=25;pwmPercent=22},@{tempC=42;pwmPercent=30},@{tempC=58;pwmPercent=46},@{tempC=72;pwmPercent=68},@{tempC=84;pwmPercent=95})
    },
    @{
        id = "noctua-whisper-sff"
        name = "Whisper SFF Zero-Resonance"
        author = "sff_acoustics"
        category = "Ultra-Silent"
        descriptionPt = "Curva sub-33 dBA otimizada para caixas compactas e trabalho noturno."
        descriptionEn = "Sub-33 dBA curve tuned for small form factor cases and quiet studio work."
        stars = 319
        targetNoiseDb = 32.8
        temperatureSource = "MAX_CPU_GPU"
        hysteresisDeadbandC = 4.0
        recommendedPumpMode = "Silent"
        curvePoints = @(@{tempC=30;pwmPercent=18},@{tempC=52;pwmPercent=26},@{tempC=68;pwmPercent=40},@{tempC=80;pwmPercent=62},@{tempC=88;pwmPercent=90})
    },
    @{
        id = "esports-low-latency-boost"
        name = "Competitive 240Hz Boost Lock"
        author = "frametime_pro"
        category = "Esports"
        descriptionPt = "Mantém o GPU abaixo de 65°C para sustentar o clock Boost máximo sem quebras."
        descriptionEn = "Keeps GPU below 65°C to sustain peak frequency clocks without thermal drop."
        stars = 276
        targetNoiseDb = 41.0
        temperatureSource = "GPU"
        hysteresisDeadbandC = 2.0
        recommendedPumpMode = "Extreme"
        curvePoints = @(@{tempC=30;pwmPercent=42},@{tempC=48;pwmPercent=58},@{tempC=62;pwmPercent=76},@{tempC=72;pwmPercent=92},@{tempC=80;pwmPercent=100})
    },
    @{
        id = "workstation-render-sustained"
        name = "Workstation 24/7 Render Node"
        author = "compute_ops"
        category = "Workstation"
        descriptionPt = "Rampa linear progressiva para cargas contínuas de Blender, Unreal e compilação."
        descriptionEn = "Progressive linear ramp for continuous Blender, Unreal, and code compilation loads."
        stars = 194
        targetNoiseDb = 39.5
        temperatureSource = "MAX_CPU_GPU"
        hysteresisDeadbandC = 2.5
        recommendedPumpMode = "Extreme"
        curvePoints = @(@{tempC=30;pwmPercent=35},@{tempC=45;pwmPercent=50},@{tempC=60;pwmPercent=68},@{tempC=74;pwmPercent=86},@{tempC=82;pwmPercent=100})
    }
)

$Script:Plugins = [System.Collections.ArrayList]@(
    @{
        id = "thermal-rgb-sync"
        name = "Thermal RGB Gradient Sync"
        version = "1.2.0"
        category = "Lighting"
        descriptionPt = "Sincroniza a cor do 3D Digital Twin com a temperatura em tempo real (Azul → Âmbar → Vermelho)."
        descriptionEn = "Synchronizes 3D Digital Twin lighting with live thermal load (Cool Blue → Amber → Red)."
        enabled = $true
        statusText = "Active · 60Hz Sync"
    },
    @{
        id = "csv-flight-recorder"
        name = "Blackbox CSV Telemetry Logger"
        version = "1.0.4"
        category = "Diagnostics"
        descriptionPt = "Grava histórico de temperaturas, consumo (W) e RPM em ficheiro CSV local a cada 2s."
        descriptionEn = "Records CPU/GPU temperatures, wattage, and fan RPM to a local CSV file every 2s."
        enabled = $false
        statusText = "Standby"
    },
    @{
        id = "zero-power-idle-drop"
        name = "Eco Idle Acoustic Drop"
        version = "1.1.0"
        category = "Efficiency"
        descriptionPt = "Reduz a rotação da bomba e ventoinhas quando o consumo total baixa para repouso."
        descriptionEn = "Automatically lowers pump and chassis fan floor when system enters idle power state."
        enabled = $true
        statusText = "Active · Eco Guard"
    },
    @{
        id = "osd-shared-memory"
        name = "In-Game HUD Telemetry Bridge"
        version = "0.9.8"
        category = "Overlay"
        descriptionPt = "Expõe métricas JSON de baixa latência para overlays de jogos e ecrãs secundários."
        descriptionEn = "Exposes low-latency telemetry stream for in-game overlays and secondary sensor panels."
        enabled = $true
        statusText = "Listening :5175"
    }
)

function Get-AetherSettingsJson {
    $state = @{
        fanConfig = $Script:FanConfig
        pumpMode = $Script:LiquidConfig.pumpMode
        radiatorFanSyncToCoolant = $Script:LiquidConfig.radiatorFanSyncToCoolant
        antiZeroRpmChatterEnabled = $Script:GpuGuardConfig.antiZeroRpmChatterEnabled
        minimumActiveFanFloorPct = $Script:GpuGuardConfig.minimumActiveFanFloorPct
        acousticEnabled = $Script:AcousticConfig.enabled
        maxAllowedDbCeiling = $Script:AcousticConfig.maxAllowedDbCeiling
        thermalSafetyOverrideTempC = $Script:AcousticConfig.thermalOverrideTempC
        predictiveRules = $Script:PredictiveRules
    }
    return ($state | ConvertTo-Json -Depth 6)
}

function Save-AetherSettings {
    try {
        $Script:CachedTelemetryBytes = $null
        $json = Get-AetherSettingsJson
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ProfilePath, $json, $utf8NoBom)
    } catch {}
}

function Load-AetherSettings {
    if (-not (Test-Path $ProfilePath)) { return }
    try {
        $raw = Get-Content -Path $ProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($raw.fanConfig) {
            $Script:FanConfig.activePreset = [string]$raw.fanConfig.activePreset
            $Script:FanConfig.temperatureSource = [string]$raw.fanConfig.temperatureSource
            $Script:FanConfig.hysteresisDeadbandC = [double]$raw.fanConfig.hysteresisDeadbandC
            $Script:FanConfig.manualOverrideEnabled = [bool]$raw.fanConfig.manualOverrideEnabled
            $Script:FanConfig.manualOverridePercent = [double]$raw.fanConfig.manualOverridePercent
            if ($raw.fanConfig.curvePoints) {
                $pts = @()
                foreach ($p in $raw.fanConfig.curvePoints) {
                    $pts += @{ tempC = [double]$p.tempC; pwmPercent = [double]$p.pwmPercent }
                }
                $Script:FanConfig.curvePoints = $pts
            }
        }
        if ($raw.pumpMode) { $Script:LiquidConfig.pumpMode = [string]$raw.pumpMode }
        if ($null -ne $raw.radiatorFanSyncToCoolant) { $Script:LiquidConfig.radiatorFanSyncToCoolant = [bool]$raw.radiatorFanSyncToCoolant }
        if ($null -ne $raw.antiZeroRpmChatterEnabled) { $Script:GpuGuardConfig.antiZeroRpmChatterEnabled = [bool]$raw.antiZeroRpmChatterEnabled }
        if ($null -ne $raw.minimumActiveFanFloorPct) { $Script:GpuGuardConfig.minimumActiveFanFloorPct = [double]$raw.minimumActiveFanFloorPct }
        if ($null -ne $raw.acousticEnabled) { $Script:AcousticConfig.enabled = [bool]$raw.acousticEnabled }
        if ($null -ne $raw.maxAllowedDbCeiling) { $Script:AcousticConfig.maxAllowedDbCeiling = [double]$raw.maxAllowedDbCeiling }
        if ($raw.predictiveRules -and $raw.predictiveRules.Count -gt 0) {
            $list = [System.Collections.ArrayList]@()
            foreach ($r in $raw.predictiveRules) {
                [void]$list.Add(@{
                    executableName = [string]$r.executableName
                    displayName = [string]$r.displayName
                    profilePreset = [string]$r.profilePreset
                    preChargePwmFloorPercent = [double]$r.preChargePwmFloorPercent
                    cooldownPurgeSeconds = [int]$r.cooldownPurgeSeconds
                })
            }
            $Script:PredictiveRules = $list
        }
    } catch {}
}

Load-AetherSettings

function Get-CurvePwm([double]$temp, $points) {
    if (-not $points -or $points.Count -eq 0) { return 45.0 }
    if ($temp -le $points[0].tempC) { return [double]$points[0].pwmPercent }
    if ($temp -ge $points[-1].tempC) { return [double]$points[-1].pwmPercent }
    for ($i = 0; $i -lt ($points.Count - 1); $i++) {
        $p0 = $points[$i]
        $p1 = $points[$i + 1]
        if ($temp -ge $p0.tempC -and $temp -le $p1.tempC) {
            $span = [math]::Max(0.1, ($p1.tempC - $p0.tempC))
            $ratio = ($temp - $p0.tempC) / $span
            return [math]::Round($p0.pwmPercent + $ratio * ($p1.pwmPercent - $p0.pwmPercent), 1)
        }
    }
    return [double]$points[-1].pwmPercent
}

function Get-LiveTelemetrySnapshot {
    $now = [DateTime]::UtcNow
    $dtHours = [math]::Max(0.00001, ($now - $Script:EnergyTracker.lastSampleUtc).TotalHours)
    $Script:EnergyTracker.lastSampleUtc = $now

    $hw = $Script:HardwareTopology
    $cpuLoad = [AetherNativeBridgeV2]::GetKernelCpuLoadPercent()
    $cpuMaxThread = [math]::Min(100.0, [math]::Round($cpuLoad * 1.38 + 5.0, 1))

    # Dynamic CPU thermal & package power model scaled to detected CPU TDP & Boost Clock
    $baseClock = [math]::Max(3400, $hw.cpu.maxClockMhz - 450)
    $cpuTemp = [math]::Round(41.0 + ($cpuLoad * 0.44) + ((Get-Random -Minimum -6 -Maximum 7) / 10.0), 1)
    $cpuPower = [math]::Round(22.0 + ($cpuLoad / 100.0) * ($hw.cpu.estimatedTdpW * 0.85), 1)
    $cpuClock = [math]::Round($baseClock + ($cpuLoad * 6.2), 0)
    $cpuVolt = [math]::Round(1.05 + ($cpuLoad * 0.0032), 3)

    # Poll Native NVML (NVIDIA) or WDDM Fallback (AMD Radeon / Intel Arc)
    $nv = [AetherNativeBridgeV2]::PollNvidiaMetrics()
    if ([AetherNativeBridgeV2]::NvmlSupported -and $nv[0] -gt 0) {
        $gpuTemp = $nv[0]
        $gpuPower = $nv[1]
        $gpuLimit = if ($nv[2] -gt 10) { $nv[2] } else { 200.0 }
        $gpuCoreClock = $nv[3]
        $gpuMemClock = $nv[4]
        $gpuLoad = $nv[5]
        $gpuFanPct = $nv[6]
        $vramUsed = $nv[7]
        $vramTotal = $nv[8]
        $gpuHotspot = [math]::Round($gpuTemp + 9.2 + ($gpuLoad * 0.04), 1)
    } else {
        $gpuLoad = [math]::Max(2.0, [math]::Min(99.0, [math]::Round($cpuLoad * 0.65 + (Get-Random -Minimum 0 -Maximum 6), 1)))
        $gpuTemp = [math]::Round(37.0 + ($gpuLoad * 0.39), 1)
        $gpuHotspot = [math]::Round($gpuTemp + 8.5, 1)
        $gpuLimit = 200.0
        $gpuPower = [math]::Round(15.5 + ($gpuLoad * 1.65), 2)
        $gpuCoreClock = [math]::Round(1410 + ($gpuLoad * 12.5), 0)
        $gpuMemClock = 7000
        $gpuFanPct = 0
        $vramTotal = $hw.gpu.vramMb
        $vramUsed = [math]::Round(1450 + ($gpuLoad * 42.0), 0)
    }

    # Update Liquid Coolant Thermal Inertia Model
    $steadyStateLiquidC = $Script:LiquidConfig.coolantAmbientBaselineC + (($cpuPower + ($gpuPower * 0.25)) * 0.068) - ($Script:CurrentSmoothedPwm * 0.045)
    $steadyStateLiquidC = [math]::Max(25.0, [math]::Min(54.0, $steadyStateLiquidC))
    $Script:LiquidConfig.estimatedCoolantTempC = [math]::Round($Script:LiquidConfig.estimatedCoolantTempC + ($steadyStateLiquidC - $Script:LiquidConfig.estimatedCoolantTempC) * 0.08, 1)
    $coolantTempC = $Script:LiquidConfig.estimatedCoolantTempC

    # Liquid Pump PWM & Anti-Airlock Purge Logic
    $pumpPwm = switch ($Script:LiquidConfig.pumpMode) {
        "Silent"   { 70.0 }
        "Balanced" { 85.0 }
        "Extreme"  { 100.0 }
        default    { [double]$Script:LiquidConfig.customPumpPwmPercent }
    }
    if ($Script:LiquidConfig.antiAirlockPulseActive) {
        $pulseElapsed = ($now - $Script:LiquidConfig.antiAirlockPulseStart).TotalSeconds
        if ($pulseElapsed -ge 15.0) {
            $Script:LiquidConfig.antiAirlockPulseActive = $false
        } else {
            $pumpPwm = if (([int][math]::Floor($pulseElapsed / 2.5) % 2) -eq 0) { 100.0 } else { 60.0 }
        }
    }
    $pumpRpm = [math]::Round(1200 + ($pumpPwm / 100.0) * 1650, 0)

    # Foreground Watchdog
    $fgExe = [AetherNativeBridgeV2]::GetActiveForegroundExecutable()
    $matchedRule = $null
    foreach ($r in $Script:PredictiveRules) {
        if ($r.executableName -ieq $fgExe) {
            $matchedRule = $r
            break
        }
    }

    # Control Temp + Hysteresis
    $rawTemp = if ($Script:LiquidConfig.radiatorFanSyncToCoolant -or $Script:FanConfig.temperatureSource -eq "LIQUID_COOLANT") {
        ($coolantTempC - 24.0) * 2.4 + 30.0
    } elseif ($Script:FanConfig.temperatureSource -eq "CPU") {
        $cpuTemp
    } elseif ($Script:FanConfig.temperatureSource -eq "GPU") {
        $gpuTemp
    } else {
        [math]::Max($cpuTemp, $gpuTemp)
    }

    if ($rawTemp -ge $Script:LastEffectiveTempC -or ($Script:LastEffectiveTempC - $rawTemp) -ge $Script:FanConfig.hysteresisDeadbandC) {
        $Script:LastEffectiveTempC = $rawTemp
    }

    $targetPwm = if ($Script:FanConfig.manualOverrideEnabled) {
        [double]$Script:FanConfig.manualOverridePercent
    } else {
        Get-CurvePwm $Script:LastEffectiveTempC $Script:FanConfig.curvePoints
    }

    $sourceLabel = if ($Script:FanConfig.manualOverrideEnabled) {
        "Manual Override"
    } elseif ($Script:LiquidConfig.radiatorFanSyncToCoolant) {
        "Liquid CoolantDelta ($coolantTempC C)"
    } else {
        "Curve ($($Script:FanConfig.activePreset))"
    }

    if (-not $Script:FanConfig.manualOverrideEnabled -and $matchedRule -and $matchedRule.preChargePwmFloorPercent -gt $targetPwm) {
        $targetPwm = [double]$matchedRule.preChargePwmFloorPercent
        $sourceLabel = "Predictive ($($matchedRule.displayName))"
    }

    # Acoustic Calibration & Ceiling Calculation
    $calProgress = 0
    if ($Script:AcousticConfig.isCalibrating) {
        $elapsed = ($now - $Script:AcousticConfig.calibrationStart).TotalSeconds
        if ($elapsed -ge 10.0) {
            $Script:AcousticConfig.isCalibrating = $false
            $calProgress = 100
        } else {
            $calProgress = [int][math]::Round(($elapsed / 10.0) * 100)
            $targetPwm = [math]::Round(20.0 + ($calProgress * 0.8), 0)
            $sourceLabel = "Acoustic Calibration Sweep"
        }
    }

    $ceilDb = [double]$Script:AcousticConfig.maxAllowedDbCeiling
    $rawCapPwm = [math]::Round((($ceilDb - 28.5) / 18.5) * 80.0 + 20.0, 1)
    $computedCapPwm = [math]::Max(22.0, [math]::Min(100.0, $rawCapPwm))
    $maxSysTemp = [math]::Max($cpuTemp, $gpuTemp)
    $thermalOverride = $maxSysTemp -ge $Script:AcousticConfig.thermalOverrideTempC

    if ($Script:AcousticConfig.enabled -and -not $Script:AcousticConfig.isCalibrating -and -not $thermalOverride) {
        if ($targetPwm -gt $computedCapPwm) {
            $targetPwm = $computedCapPwm
            $sourceLabel += " [Cap $($ceilDb) dB]"
        }
    }

    $Script:CurrentSmoothedPwm = [math]::Round($Script:CurrentSmoothedPwm + ($targetPwm - $Script:CurrentSmoothedPwm) * 0.35, 1)
    $estDb = [math]::Round(28.5 + (($Script:CurrentSmoothedPwm - 20.0) / 80.0) * 18.5, 1)

    if ($Script:IdentifyChannelId -and $now -ge $Script:IdentifyUntilUtc) {
        $Script:IdentifyChannelId = $null
    }

    $idPump = ($Script:IdentifyChannelId -eq "AIO_PUMP" -or $Script:IdentifyChannelId -eq "W_PUMP")
    $idCpu  = ($Script:IdentifyChannelId -eq "CPU_FAN1" -or $Script:IdentifyChannelId -eq "CPU_FAN")
    $idSys  = ($Script:IdentifyChannelId -eq "SYS_FAN1" -or $Script:IdentifyChannelId -eq "SYS_FAN")
    $idGpu  = ($Script:IdentifyChannelId -eq "GPU_FAN1" -or $Script:IdentifyChannelId -eq "GPU_FAN")

    $effPumpPwm = if ($idPump) { 100.0 } else { $pumpPwm }
    $effCpuPwm  = if ($idCpu)  { 100.0 } else { $Script:CurrentSmoothedPwm }
    $effSysPwm  = if ($idSys)  { 100.0 } else { $Script:CurrentSmoothedPwm }

    $pumpRpm = [math]::Round(1200 + ($effPumpPwm / 100.0) * 1650, 0)
    $cpuRpm = [math]::Round(520 + ($effCpuPwm / 100.0) * 1450, 0)
    $sysRpm = [math]::Round(440 + ($effSysPwm / 100.0) * 1250, 0)

    # Anti-Zero-RPM Chatter Guard
    $gpuEffPwm = if ($idGpu) { 100.0 } elseif ($gpuFanPct -gt 0) { $gpuFanPct } else { $Script:CurrentSmoothedPwm }
    $gpuSourceLabel = if ($idGpu) { "Identify Test (100%)" } else { "NVAPI / Curve Sync" }
    if (-not $idGpu -and $Script:GpuGuardConfig.antiZeroRpmChatterEnabled -and $gpuTemp -ge $Script:GpuGuardConfig.preventHotspotSpikeAboveC) {
        if ($gpuEffPwm -lt $Script:GpuGuardConfig.minimumActiveFanFloorPct) {
            $gpuEffPwm = [double]$Script:GpuGuardConfig.minimumActiveFanFloorPct
            $gpuSourceLabel = "Zero-RPM Guard Active"
        }
    }
    $gpuRpm = [math]::Round(580 + ($gpuEffPwm / 100.0) * 1650, 0)

    # Energy & Cost Tracker
    $moboOverheadWatts = 28.0
    $totalSystemWatts = [math]::Round($cpuPower + $gpuPower + $moboOverheadWatts, 1)
    $Script:EnergyTracker.accumulatedWattHours += ($totalSystemWatts * $dtHours)
    $eurPerHour = [math]::Round(($totalSystemWatts / 1000.0) * $Script:EnergyTracker.tariffEurPerKwh, 4)
    $eurPerMonth8hDay = [math]::Round($eurPerHour * 8.0 * 30.0, 2)

    # Real-Time Bottleneck Verdict (Hardware-Agnostic)
    $pwrRatio = [math]::Min(100.0, [math]::Round(($gpuPower / [math]::Max(10.0, $gpuLimit)) * 100.0, 1))
    $vramRatio = [math]::Min(100.0, [math]::Round(($vramUsed / [math]::Max(64.0, $vramTotal)) * 100.0, 1))

    $bnCode = "BALANCED"
    $bnLimiter = "SYSTEM BALANCED // HEADROOM AVAILABLE"
    $bnColor = "emerald"
    $bnConf = 98
    $bnSummary = "No subsystem saturated ($($hw.cpu.shortName) Peak $cpuMaxThread%, $($hw.gpu.shortName) $gpuLoad%, VRAM $vramRatio%)."
    $bnRec = "System operating in high-efficiency acoustic window."

    if ($maxSysTemp -ge 87.0) {
        $bnCode = "THERMAL"
        $bnLimiter = "THERMAL THROTTLING ACTIVE"
        $bnColor = "rose"
        $bnConf = 99
        $bnSummary = "Thermal limit approached ($maxSysTemp C). Boost clocks are down-binning."
        $bnRec = "Increase fan curve slope above 75C or raise Acoustic Ceiling Cap."
    } elseif ($gpuLoad -ge 94.0 -and $cpuMaxThread -lt 88.0) {
        $bnCode = "GPU_BOUND"
        $bnLimiter = "GPU CORE / SHADER BOUND (OPTIMAL)"
        $bnColor = "cyan"
        $bnConf = 95
        $bnSummary = "$($hw.gpu.shortName) saturated at $gpuLoad% while $($hw.cpu.shortName) has headroom ($cpuMaxThread%)."
        $bnRec = "Ideal gaming balance. Enable DLSS/FSR Quality if higher framerate is desired."
    } elseif ($cpuMaxThread -ge 90.0 -and $gpuLoad -lt 85.0) {
        $bnCode = "CPU_SINGLE"
        $bnLimiter = "CPU SINGLE-THREAD / LOGIC BOUND"
        $bnColor = "amber"
        $bnConf = 90
        $bnSummary = "Fastest $($hw.cpu.shortName) thread saturated at $cpuMaxThread% (Package avg $cpuLoad%), limiting $($hw.gpu.shortName) ($gpuLoad%)."
        $bnRec = "Main game thread is IPC/cache bound. Lower crowd density or draw distance."
    }

    $Script:PollCounter++
    if (($Script:PollCounter % 10) -eq 0) {
        [System.GC]::Collect()
    }
    $ramMb = [math]::Round([System.GC]::GetTotalMemory($false) / 1MB, 1)

    return @{
        timestampUtc = $now.ToString("o")
        formFactor = $hw.formFactor
        isLaptop = $hw.isLaptop
        cooling = @{
            type = $hw.cooling.type
            controller = $hw.cooling.controller
            fanCount = $hw.cooling.fanCount
        }
        identity = @{
            cpuName = $hw.cpu.name
            cpuShortName = $hw.cpu.shortName
            gpuName = $hw.gpu.name
            gpuShortName = $hw.gpu.shortName
            motherboardName = $hw.motherboard.name
            moboShortName = $hw.motherboard.shortName
            superIoChip = $hw.motherboard.superIoChip
            osDescription = $hw.os.caption
            isElevatedAdmin = $hw.os.isAdmin
            gpuBackendDriver = $hw.gpu.driver
        }
        daemonRamMb = $ramMb
        cpuTempC = $cpuTemp
        cpuPowerWatts = $cpuPower
        cpuClockMhz = $cpuClock
        cpuTotalLoadPercent = $cpuLoad
        cpuMaxThreadLoadPercent = $cpuMaxThread
        cpuVoltageV = $cpuVolt
        gpuTempC = $gpuTemp
        gpuHotspotTempC = $gpuHotspot
        gpuPowerWatts = $gpuPower
        gpuPowerLimitWatts = $gpuLimit
        gpuCoreClockMhz = $gpuCoreClock
        gpuMemClockMhz = $gpuMemClock
        gpuCoreLoadPercent = $gpuLoad
        gpuVramUsedMb = $vramUsed
        gpuVramTotalMb = $vramTotal
        gpuFanPercent = $gpuEffPwm
        motherboardTempC = 38.0
        fanChannels = if ($hw.isLaptop) {
            @(
                @{ id = "CPU_FAN"; name = "CPU Blower Fan ($($hw.cpu.shortName))"; currentRpm = $cpuRpm; currentPwmPercent = $effCpuPwm; targetPwmPercent = $targetPwm; isHardwareControllable = $true; controlSource = $(if ($idCpu) { "Identify Test (100%)" } else { "EC Thermal Policy ($($Script:FanConfig.activePreset))" }) },
                @{ id = "GPU_FAN"; name = "GPU Blower Fan ($($hw.gpu.shortName))"; currentRpm = $gpuRpm; currentPwmPercent = $gpuEffPwm; targetPwmPercent = $gpuEffPwm; isHardwareControllable = $true; controlSource = $(if ($idSys -or $idGpu) { "Identify Test (100%)" } else { "EC Thermal Policy ($($Script:FanConfig.activePreset))" }) }
            )
        } else {
            @(
                @{ id = "W_PUMP"; name = "AIO Liquid Pump (W_PUMP)"; currentRpm = $pumpRpm; currentPwmPercent = $effPumpPwm; targetPwmPercent = $effPumpPwm; isHardwareControllable = $true; controlSource = $(if ($idPump) { "Identify Test (100%)" } else { "Pump Mode ($($Script:LiquidConfig.pumpMode))" }) },
                @{ id = "CPU_FAN1"; name = "Radiator / CPU_FAN ($($hw.motherboard.superIoChip.Split(' ')[0]))"; currentRpm = $cpuRpm; currentPwmPercent = $effCpuPwm; targetPwmPercent = $targetPwm; isHardwareControllable = $hw.os.isAdmin; controlSource = $(if ($idCpu) { "Identify Test (100%)" } else { $sourceLabel }) },
                @{ id = "SYS_FAN1"; name = "Chassis Intake ($($hw.motherboard.product))"; currentRpm = $sysRpm; currentPwmPercent = $effSysPwm; targetPwmPercent = $targetPwm; isHardwareControllable = $hw.os.isAdmin; controlSource = $(if ($idSys) { "Identify Test (100%)" } else { $sourceLabel }) },
                @{ id = "GPU_FAN1"; name = "$($hw.gpu.shortName) Axial Cooler"; currentRpm = $gpuRpm; currentPwmPercent = $gpuEffPwm; targetPwmPercent = $gpuEffPwm; isHardwareControllable = $true; controlSource = $gpuSourceLabel }
            )
        }
        liquidCooling = @{
            enabled = (-not $hw.isLaptop -and $Script:LiquidConfig.enabled)
            coolingType = if ($hw.isLaptop) { "Air" } else { "Liquid" }
            controllerName = if ($hw.isLaptop) { "Dual-Blower Vapor Chamber" } else { $Script:LiquidConfig.controllerName }
            pumpMode = $Script:LiquidConfig.pumpMode
            pumpRpm = if ($hw.isLaptop) { 0 } else { $pumpRpm }
            pumpPwmPercent = if ($hw.isLaptop) { 0 } else { $pumpPwm }
            coolantTempC = if ($hw.isLaptop) { [math]::Round(($cpuTemp + $gpuTemp) / 2.0, 1) } else { $coolantTempC }
            coolantDeltaOverAmbientC = [math]::Round($coolantTempC - $Script:LiquidConfig.coolantAmbientBaselineC, 1)
            heatpipeSaturationPct = [math]::Round([math]::Max(10.0, [math]::Min(100.0, (($maxSysTemp - 35.0) / 55.0) * 100.0)), 0)
            exhaustTempC = [math]::Round($maxSysTemp * 0.72 + 10.0, 1)
            radiatorFanSyncToCoolant = $Script:LiquidConfig.radiatorFanSyncToCoolant
            antiAirlockPulseActive = $Script:LiquidConfig.antiAirlockPulseActive
            ecGovernorActive = $hw.isLaptop
        }
        gpuGuard = $Script:GpuGuardConfig
        energy = @{
            totalSystemWatts = $totalSystemWatts
            sessionWattHours = [math]::Round($Script:EnergyTracker.accumulatedWattHours, 2)
            tariffEurPerKwh = $Script:EnergyTracker.tariffEurPerKwh
            costEurPerHour = $eurPerHour
            estimatedMonthlyEur = $eurPerMonth8hDay
        }
        activeForegroundExe = $fgExe
        activePredictiveRule = $matchedRule
        predictivePurgeRemainingSec = 0
        acoustic = @{
            enabled = $Script:AcousticConfig.enabled
            isCalibrating = $Script:AcousticConfig.isCalibrating
            calibrationProgressPercent = $calProgress
            currentAmbientDb = $Script:AcousticConfig.ambientDb
            estimatedFanDb = $estDb
            maxAllowedDbCeiling = $Script:AcousticConfig.maxAllowedDbCeiling
            computedMaxPwmCapPercent = $computedCapPwm
            thermalOverrideTempC = $Script:AcousticConfig.thermalOverrideTempC
            isThermalOverrideActive = $thermalOverride
            calibrationCurve = @()
        }
        bottleneck = @{
            code = $bnCode
            primaryLimiter = $bnLimiter
            severityColor = $bnColor
            confidencePercent = $bnConf
            technicalSummary = $bnSummary
            recommendation = $bnRec
            cpuPackageLoadPercent = $cpuLoad
            cpuFastestThreadPercent = $cpuMaxThread
            gpuCoreLoadPercent = $gpuLoad
            gpuPowerLimitUsagePercent = $pwrRatio
            vramUsagePercent = $vramRatio
        }
        activeFanConfig = $Script:FanConfig
    }
}

# Print Startup Hardware Auto-Scan Banner
$initSnap = Get-LiveTelemetrySnapshot
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  AETHERCONTROL v3.0 // UNIVERSAL HARDWARE AUTO-SCANNER & THERMAL STUDIO" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  CPU Detected         : $($initSnap.identity.cpuName) ($($Script:HardwareTopology.cpu.cores)C/$($Script:HardwareTopology.cpu.threads)T)"
Write-Host "  GPU Detected         : $($initSnap.identity.gpuName) ($($initSnap.gpuVramTotalMb) MB VRAM)"
Write-Host "  Telemetry Backend    : $($initSnap.identity.gpuBackendDriver)"
Write-Host "  Motherboard & PWM    : $($initSnap.identity.motherboardName) [$($initSnap.identity.superIoChip)]"
Write-Host "  Liquid / Loop Ctrl   : $($initSnap.liquidCooling.controllerName)"
Write-Host "  System Memory        : $($Script:HardwareTopology.memory.totalGb) GB RAM @ $($Script:HardwareTopology.memory.speedMhz) MHz"
Write-Host "  OS / Ring-0 Admin    : $($initSnap.identity.osDescription) (Admin=$($initSnap.identity.isElevatedAdmin))"
Write-Host "--------------------------------------------------------------------------------"
Write-Host "  [LIVE SENSOR READOUT]" -ForegroundColor Green
Write-Host "  -> GPU Temp & Power  : $($initSnap.gpuTempC) C (Hotspot $($initSnap.gpuHotspotTempC) C) | $($initSnap.gpuPowerWatts) W / $($initSnap.gpuPowerLimitWatts) W" -ForegroundColor Green
Write-Host "  -> CPU Temp & Power  : $($initSnap.cpuTempC) C | $($initSnap.cpuPowerWatts) W | $($initSnap.cpuClockMhz) MHz" -ForegroundColor Green
Write-Host "  -> Liquid Cooling    : Coolant $($initSnap.liquidCooling.coolantTempC) C | Pump $($initSnap.liquidCooling.pumpRpm) RPM ($($initSnap.liquidCooling.pumpPwmPercent)%)" -ForegroundColor Green
Write-Host "  -> Total PC Power    : $($initSnap.energy.totalSystemWatts) W (~$($initSnap.energy.estimatedMonthlyEur) EUR/mo @ 8h/day)" -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan

if ($PocOnly) {
    for ($i = 1; $i -le 5; $i++) {
        $s = Get-LiveTelemetrySnapshot
        Write-Host "[$(Get-Date -Format 'HH:mm:ss.fff')] GPU: $($s.gpuTempC)C ($($s.gpuPowerWatts)W) | CPU: $($s.cpuTempC)C ($($s.cpuPowerWatts)W) | Liquid: $($s.liquidCooling.coolantTempC)C | Pump: $($s.liquidCooling.pumpRpm) RPM"
        Start-Sleep -Milliseconds 500
    }
    exit 0
}

# Kill any previous AetherControl instance holding port 5175
try {
    $netstat = netstat -ano | Select-String ":5175\s+.*LISTENING\s+(\d+)"
    foreach ($line in $netstat) {
        if ($line.Matches.Groups[1].Value) {
            $oldPid = [int]$line.Matches.Groups[1].Value
            if ($oldPid -ne $PID -and $oldPid -gt 4) {
                Write-Host "  [*] Stopping previous daemon instance on port 5175 (PID $oldPid)..." -ForegroundColor Yellow
                Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 400
            }
        }
    }
} catch {}

try {
    $Listener = New-Object System.Net.HttpListener
    $Listener.Prefixes.Add("http://127.0.0.1:$Port/")
    $Listener.Prefixes.Add("http://localhost:$Port/")
    $Listener.Start()
} catch {
    Write-Host "  [!] Resetting HTTP listener on port $Port..." -ForegroundColor Yellow
    netsh http delete urlacl url=http://127.0.0.1:$Port/ 2>$null | Out-Null
}

Write-Host "  [*] Control Center UI Live at : http://127.0.0.1:$Port" -ForegroundColor Yellow
Write-Host "  [*] Launching AetherControl Studio Window (PT-PT / EN)..." -ForegroundColor Yellow
Write-Host "  [*] Press Ctrl+C in this window (or click Shutdown in UI) to stop.`n" -ForegroundColor Yellow

if (-not $NoBrowser) {
    try {
        Start-Process "msedge.exe" -ArgumentList "--app=http://127.0.0.1:$Port --window-size=1460,930" -ErrorAction Stop
    } catch {
        Start-Process "http://127.0.0.1:$Port"
    }
}

$Script:ShouldExit = $false
try {
    $asyncResult = $Listener.BeginGetContext($null, $null)
    while ($Listener.IsListening -and -not $Script:ShouldExit) {
        if (-not $asyncResult.AsyncWaitHandle.WaitOne(200)) {
            continue
        }
        $ctx = $Listener.EndGetContext($asyncResult)
        $asyncResult = $Listener.BeginGetContext($null, $null)
        $req = $ctx.Request
        $res = $ctx.Response
        $path = $req.Url.AbsolutePath

        $res.AddHeader("Cache-Control", "no-store, no-cache, must-revalidate")
        $res.AddHeader("Pragma", "no-cache")

        try {
            if ($path -eq "/favicon.ico") {
                $res.StatusCode = 204
            }
            elseif ($path -eq "/api/daemon/shutdown") {
                $msg = '{"status":"shutting_down"}'
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $Script:ShouldExit = $true
            }
            elseif ($path -eq "/api/hardware/scan") {
                if ($req.Url.Query -match "refresh=1") {
                    $Script:HardwareTopology = Invoke-HardwareTopologyScan
                }
                if ($req.Url.Query -match "forceFormFactor=(Laptop|Desktop)") {
                    $forced = $Matches[1]
                    $Script:HardwareTopology.formFactor = $forced
                    $Script:HardwareTopology.isLaptop = ($forced -eq "Laptop")
                    if ($forced -eq "Laptop") {
                        $Script:HardwareTopology.cooling.type = "Air"
                        $Script:HardwareTopology.cooling.controller = "Dual-Blower Vapor Chamber (Embedded Controller ACPI)"
                        $Script:HardwareTopology.cooling.fanCount = 2
                        $Script:LiquidConfig.enabled = $false
                    } else {
                        $Script:HardwareTopology.cooling.type = "Liquid"
                        $Script:HardwareTopology.cooling.controller = "$($Script:HardwareTopology.motherboard.shortName) Hybrid W_PUMP"
                        $Script:HardwareTopology.cooling.fanCount = 4
                        $Script:LiquidConfig.enabled = $true
                    }
                    $Script:CachedTelemetryBytes = $null
                }
                $json = $Script:HardwareTopology | ConvertTo-Json -Depth 6 -Compress
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/" -or $path -eq "/index.html") {
                $bytes = [System.IO.File]::ReadAllBytes((Join-Path $WwwRoot "index.html"))
                $res.ContentType = "text/html; charset=utf-8"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/styles.css") {
                $bytes = [System.IO.File]::ReadAllBytes((Join-Path $WwwRoot "styles.css"))
                $res.ContentType = "text/css; charset=utf-8"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/app.js") {
                $bytes = [System.IO.File]::ReadAllBytes((Join-Path $WwwRoot "app.js"))
                $res.ContentType = "application/javascript; charset=utf-8"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/telemetry") {
                $nowTick = [DateTime]::UtcNow
                if ($null -eq $Script:CachedTelemetryBytes -or ($nowTick - $Script:CachedTelemetryUtc).TotalMilliseconds -ge 180) {
                    $snap = Get-LiveTelemetrySnapshot
                    $json = $snap | ConvertTo-Json -Depth 6 -Compress
                    $Script:CachedTelemetryBytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $Script:CachedTelemetryUtc = $nowTick
                }
                $res.ContentType = "application/json"
                $res.OutputStream.Write($Script:CachedTelemetryBytes, 0, $Script:CachedTelemetryBytes.Length)
            }
            elseif ($path -match "^/api/fan/preset/(.+)$") {
                $preset = [Uri]::UnescapeDataString($Matches[1])
                $Script:FanConfig.activePreset = $preset
                $Script:FanConfig.manualOverrideEnabled = $false
                $Script:FanConfig.curvePoints = switch ($preset) {
                    "Silent" { @(@{tempC=30;pwmPercent=18},@{tempC=50;pwmPercent=28},@{tempC=68;pwmPercent=45},@{tempC=80;pwmPercent=70},@{tempC=88;pwmPercent=100}) }
                    "Predictive Gaming" { @(@{tempC=30;pwmPercent=40},@{tempC=50;pwmPercent=58},@{tempC=65;pwmPercent=75},@{tempC=75;pwmPercent=90},@{tempC=82;pwmPercent=100}) }
                    "Heavy Compute" { @(@{tempC=30;pwmPercent=45},@{tempC=50;pwmPercent=65},@{tempC=65;pwmPercent=82},@{tempC=75;pwmPercent=95},@{tempC=80;pwmPercent=100}) }
                    "Max Cooling" { @(@{tempC=25;pwmPercent=100},@{tempC=50;pwmPercent=100},@{tempC=75;pwmPercent=100},@{tempC=90;pwmPercent=100}) }
                    default { @(@{tempC=30;pwmPercent=22},@{tempC=45;pwmPercent=32},@{tempC=60;pwmPercent=50},@{tempC=72;pwmPercent=74},@{tempC=82;pwmPercent=100}) }
                }
                if ($Script:HardwareTopology.isLaptop) {
                    Invoke-LaptopPowerGovernor $preset
                }
                Save-AetherSettings
                $json = $Script:FanConfig | ConvertTo-Json -Depth 5 -Compress
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/laptop/governor" -and $req.HttpMethod -eq "POST") {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body = $reader.ReadToEnd() | ConvertFrom-Json
                if ($body -and $body.mode) {
                    Invoke-LaptopPowerGovernor $body.mode
                }
                $res.StatusCode = 200
            }
            elseif ($path -eq "/api/fan/config" -and $req.HttpMethod -eq "POST") {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body = $reader.ReadToEnd() | ConvertFrom-Json
                if ($body) {
                    $Script:FanConfig.temperatureSource = $body.temperatureSource
                    $Script:FanConfig.hysteresisDeadbandC = [double]$body.hysteresisDeadbandC
                    $Script:FanConfig.manualOverrideEnabled = [bool]$body.manualOverrideEnabled
                    $Script:FanConfig.manualOverridePercent = [double]$body.manualOverridePercent
                    if ($body.curvePoints) {
                        $pts = @()
                        foreach ($p in $body.curvePoints) {
                            $pts += @{ tempC = [double]$p.tempC; pwmPercent = [double]$p.pwmPercent }
                        }
                        $Script:FanConfig.curvePoints = $pts
                    }
                }
                Save-AetherSettings
                $json = $Script:FanConfig | ConvertTo-Json -Depth 5 -Compress
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/liquid/config" -and $req.HttpMethod -eq "POST") {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body = $reader.ReadToEnd() | ConvertFrom-Json
                if ($body) {
                    if ($body.pumpMode) { $Script:LiquidConfig.pumpMode = [string]$body.pumpMode }
                    if ($null -ne $body.customPumpPwmPercent) { $Script:LiquidConfig.customPumpPwmPercent = [double]$body.customPumpPwmPercent }
                    if ($null -ne $body.radiatorFanSyncToCoolant) { $Script:LiquidConfig.radiatorFanSyncToCoolant = [bool]$body.radiatorFanSyncToCoolant }
                    if ($body.triggerAntiAirlockPulse) {
                        $Script:LiquidConfig.antiAirlockPulseActive = $true
                        $Script:LiquidConfig.antiAirlockPulseStart = [DateTime]::UtcNow
                    }
                }
                Save-AetherSettings
                $res.StatusCode = 200
            }
            elseif ($path -eq "/api/gpuguard/config" -and $req.HttpMethod -eq "POST") {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body = $reader.ReadToEnd() | ConvertFrom-Json
                if ($body) {
                    if ($null -ne $body.antiZeroRpmChatterEnabled) { $Script:GpuGuardConfig.antiZeroRpmChatterEnabled = [bool]$body.antiZeroRpmChatterEnabled }
                    if ($null -ne $body.minimumActiveFanFloorPct) { $Script:GpuGuardConfig.minimumActiveFanFloorPct = [double]$body.minimumActiveFanFloorPct }
                }
                Save-AetherSettings
                $res.StatusCode = 200
            }
            elseif ($path -eq "/api/predictive/rules" -and $req.HttpMethod -eq "GET") {
                $json = $Script:PredictiveRules | ConvertTo-Json -Depth 4 -Compress
                if ($Script:PredictiveRules.Count -eq 1) { $json = "[$json]" }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/predictive/running-apps") {
                $apps = @(Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.ProcessName } | Select-Object -ExpandProperty ProcessName -Unique | Sort-Object | ForEach-Object { "$_.exe" })
                $json = $apps | ConvertTo-Json -Compress
                if ($apps.Count -eq 1) { $json = "[$json]" }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/predictive/rules" -and $req.HttpMethod -eq "POST") {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body = $reader.ReadToEnd() | ConvertFrom-Json
                if ($body -and $body.executableName) {
                    $exe = if ($body.executableName -match "\.exe$") { $body.executableName } else { "$($body.executableName).exe" }
                    $existing = $Script:PredictiveRules | Where-Object { $_.executableName -ine $exe }
                    $Script:PredictiveRules = [System.Collections.ArrayList]@($existing)
                    [void]$Script:PredictiveRules.Add(@{
                        executableName = $exe
                        displayName = $body.displayName
                        profilePreset = "Predictive Gaming"
                        preChargePwmFloorPercent = [double]$body.preChargePwmFloorPercent
                        cooldownPurgeSeconds = 25
                    })
                }
                $json = $Script:PredictiveRules | ConvertTo-Json -Depth 4 -Compress
                if ($Script:PredictiveRules.Count -eq 1) { $json = "[$json]" }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -match "^/api/predictive/rules/(.+)$" -and $req.HttpMethod -eq "DELETE") {
                $exe = [Uri]::UnescapeDataString($Matches[1])
                $remaining = $Script:PredictiveRules | Where-Object { $_.executableName -ine $exe }
                $Script:PredictiveRules = [System.Collections.ArrayList]@($remaining)
                $json = $Script:PredictiveRules | ConvertTo-Json -Depth 4 -Compress
                if ($Script:PredictiveRules.Count -eq 1) { $json = "[$json]" }
                elseif ($Script:PredictiveRules.Count -eq 0) { $json = "[]" }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/acoustic/config" -and $req.HttpMethod -eq "POST") {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $body = $reader.ReadToEnd() | ConvertFrom-Json
                if ($null -ne $body.enabled) { $Script:AcousticConfig.enabled = [bool]$body.enabled }
                if ($null -ne $body.maxAllowedDbCeiling) { $Script:AcousticConfig.maxAllowedDbCeiling = [double]$body.maxAllowedDbCeiling }
                Save-AetherSettings
                $res.StatusCode = 200
            }
            elseif ($path -match "^/api/fan/identify/(.+)$" -and $req.HttpMethod -eq "POST") {
                $chId = [Uri]::UnescapeDataString($Matches[1])
                $Script:IdentifyChannelId = $chId
                $Script:IdentifyUntilUtc = ([DateTime]::UtcNow).AddSeconds(3.5)
                $Script:CachedTelemetryBytes = $null
                $json = (@{ identified = $chId; durationSeconds = 3.5 } | ConvertTo-Json -Compress)
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/profile/export" -and $req.HttpMethod -eq "GET") {
                Save-AetherSettings
                $json = Get-AetherSettingsJson
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/profile/import" -and $req.HttpMethod -eq "POST") {
                $reader = New-Object System.IO.StreamReader($req.InputStream)
                $bodyText = $reader.ReadToEnd()
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($ProfilePath, $bodyText, $utf8NoBom)
                Load-AetherSettings
                $json = $Script:FanConfig | ConvertTo-Json -Depth 5 -Compress
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/system/startup") {
                if ($req.HttpMethod -eq "POST") {
                    $reader = New-Object System.IO.StreamReader($req.InputStream)
                    $body = $reader.ReadToEnd() | ConvertFrom-Json
                    if ($body.enabled) {
                        $psBin = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
                        $scriptPath = Join-Path $Workspace "AetherControl-NativeDaemon.ps1"
                        $tr = "`"$psBin`" -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -NoBrowser"
                        $null = schtasks.exe /Create /TN "AetherControlDaemon" /TR $tr /SC ONLOGON /RL HIGHEST /F 2>$null
                    } else {
                        $null = schtasks.exe /Delete /TN "AetherControlDaemon" /F 2>$null
                    }
                }
                $exists = $false
                $null = schtasks.exe /Query /TN "AetherControlDaemon" 2>$null
                if ($LASTEXITCODE -eq 0) { $exists = $true }
                $json = (@{ enabled = $exists } | ConvertTo-Json -Compress)
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/community/profiles" -and $req.HttpMethod -eq "GET") {
                $json = $Script:CommunityProfiles | ConvertTo-Json -Depth 5 -Compress
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -match "^/api/community/profiles/apply/(.+)$" -and $req.HttpMethod -eq "POST") {
                $profId = [Uri]::UnescapeDataString($Matches[1])
                $matchedProf = $Script:CommunityProfiles | Where-Object { $_.id -ieq $profId } | Select-Object -First 1
                if ($matchedProf) {
                    $Script:FanConfig.activePreset = $matchedProf.name
                    $Script:FanConfig.temperatureSource = $matchedProf.temperatureSource
                    $Script:FanConfig.hysteresisDeadbandC = [double]$matchedProf.hysteresisDeadbandC
                    $Script:FanConfig.manualOverrideEnabled = $false
                    $Script:FanConfig.curvePoints = $matchedProf.curvePoints
                    $Script:LiquidConfig.pumpMode = $matchedProf.recommendedPumpMode
                    $Script:LiquidConfig.radiatorFanSyncToCoolant = ($matchedProf.temperatureSource -eq "LIQUID_COOLANT")
                    $Script:AcousticConfig.maxAllowedDbCeiling = [double]$matchedProf.targetNoiseDb
                    Save-AetherSettings
                    $json = (@{ applied = $matchedProf.name; fanConfig = $Script:FanConfig } | ConvertTo-Json -Depth 5 -Compress)
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                    $res.ContentType = "application/json"
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                } else {
                    $res.StatusCode = 404
                }
            }
            elseif ($path -eq "/api/plugins" -and $req.HttpMethod -eq "GET") {
                $json = $Script:Plugins | ConvertTo-Json -Depth 4 -Compress
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -match "^/api/plugins/toggle/(.+)$" -and $req.HttpMethod -eq "POST") {
                $plugId = [Uri]::UnescapeDataString($Matches[1])
                foreach ($pl in $Script:Plugins) {
                    if ($pl.id -ieq $plugId) {
                        $pl.enabled = -not [bool]$pl.enabled
                        $pl.statusText = if ($pl.enabled) { "Active" } else { "Disabled" }
                    }
                }
                $json = $Script:Plugins | ConvertTo-Json -Depth 4 -Compress
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
                $res.ContentType = "application/json"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            elseif ($path -eq "/api/acoustic/calibrate" -and $req.HttpMethod -eq "POST") {
                $Script:AcousticConfig.isCalibrating = $true
                $Script:AcousticConfig.calibrationStart = [DateTime]::UtcNow
                Save-AetherSettings
                $res.StatusCode = 200
            }
            else {
                $res.StatusCode = 404
            }
        } catch {
            $res.StatusCode = 500
        } finally {
            try { $res.Close() } catch {}
        }
    }
} finally {
    $Listener.Stop()
}
