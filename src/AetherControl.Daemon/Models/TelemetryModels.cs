using System;
using System.Collections.Generic;

namespace AetherControl.Daemon.Models;

public sealed record SystemHardwareIdentity(
    string CpuName,
    string CpuShortName,
    string GpuName,
    string GpuShortName,
    string MotherboardName,
    string MoboShortName,
    string SuperIoChip,
    string OsDescription,
    bool IsElevatedAdmin,
    string GpuBackendDriver
);

public sealed record FanChannelTelemetry(
    string Id,
    string Name,
    double CurrentRpm,
    double CurrentPwmPercent,
    double TargetPwmPercent,
    bool IsHardwareControllable,
    string ControlSource
);

public sealed record CurvePoint(double TempC, double PwmPercent);

public sealed class FanProfileConfig
{
    public string ActivePreset { get; set; } = "Balanced";
    public string TemperatureSource { get; set; } = "MAX_CPU_GPU"; // CPU, GPU, MAX_CPU_GPU, LIQUID_COOLANT
    public double HysteresisDeadbandC { get; set; } = 3.0;
    public double MaxStepUpPercentPerSec { get; set; } = 15.0;
    public double MaxStepDownPercentPerSec { get; set; } = 3.0;
    public bool ManualOverrideEnabled { get; set; } = false;
    public double ManualOverridePercent { get; set; } = 50.0;
    public List<CurvePoint> CurvePoints { get; set; } = new()
    {
        new(30, 22),
        new(45, 32),
        new(60, 50),
        new(72, 74),
        new(82, 100)
    };
}

public sealed record LiquidCoolingStatus(
    bool Enabled,
    string ControllerName,
    string PumpMode,
    double PumpRpm,
    double PumpPwmPercent,
    double CoolantTempC,
    double CoolantDeltaOverAmbientC,
    bool RadiatorFanSyncToCoolant,
    bool AntiAirlockPulseActive
);

public sealed record GpuGuardStatus(
    bool AntiZeroRpmChatterEnabled,
    double MinimumActiveFanFloorPct,
    double PreventHotspotSpikeAboveC
);

public sealed record EnergyStatus(
    double TotalSystemWatts,
    double SessionWattHours,
    double TariffEurPerKwh,
    double CostEurPerHour,
    double EstimatedMonthlyEur
);

public sealed record PredictiveRule(
    string ExecutableName,
    string DisplayName,
    string ProfilePreset,
    double PreChargePwmFloorPercent,
    int CooldownPurgeSeconds
);

public sealed record AcousticStatus(
    bool Enabled,
    bool IsCalibrating,
    int CalibrationProgressPercent,
    double CurrentAmbientDb,
    double EstimatedFanDb,
    double MaxAllowedDbCeiling,
    double ComputedMaxPwmCapPercent,
    double ThermalOverrideTempC,
    bool IsThermalOverrideActive,
    List<AcousticCalibrationPoint> CalibrationCurve
);

public sealed record AcousticCalibrationPoint(double PwmPercent, double MeasuredDb, int EstimatedRpm);

public sealed record BottleneckVerdict(
    string Code,
    string PrimaryLimiter,
    string SeverityColor,
    int ConfidencePercent,
    string TechnicalSummary,
    string Recommendation,
    double CpuPackageLoadPercent,
    double CpuFastestThreadPercent,
    double GpuCoreLoadPercent,
    double GpuPowerLimitUsagePercent,
    double VramUsagePercent
);

public sealed record TelemetrySnapshot(
    DateTime TimestampUtc,
    SystemHardwareIdentity Identity,
    double DaemonRamMb,
    // CPU Metrics
    double CpuTempC,
    double CpuPowerWatts,
    double CpuClockMhz,
    double CpuTotalLoadPercent,
    double CpuMaxThreadLoadPercent,
    double CpuVoltageV,
    // GPU Metrics
    double GpuTempC,
    double GpuHotspotTempC,
    double GpuPowerWatts,
    double GpuPowerLimitWatts,
    double GpuCoreClockMhz,
    double GpuMemClockMhz,
    double GpuCoreLoadPercent,
    double GpuVramUsedMb,
    double GpuVramTotalMb,
    double GpuFanPercent,
    // Motherboard, Fans & Liquid Loop
    double MotherboardTempC,
    List<FanChannelTelemetry> FanChannels,
    LiquidCoolingStatus LiquidCooling,
    GpuGuardStatus GpuGuard,
    EnergyStatus Energy,
    // Differentiators
    string ActiveForegroundExe,
    PredictiveRule? ActivePredictiveRule,
    int PredictivePurgeRemainingSec,
    AcousticStatus Acoustic,
    BottleneckVerdict Bottleneck,
    FanProfileConfig ActiveFanConfig
);
