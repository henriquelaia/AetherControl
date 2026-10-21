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
    bool AntiAirlockPulseActive,
    int ThermalEquilibriumPct = 38
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

public sealed class PersistedUserSettings
{
    public FanProfileConfig FanConfig { get; set; } = new();
    public string PumpMode { get; set; } = "Balanced";
    public bool RadiatorFanSyncToCoolant { get; set; }
    public bool AntiZeroRpmChatterEnabled { get; set; } = true;
    public double MinimumActiveFanFloorPct { get; set; } = 32.0;
    public bool AcousticEnabled { get; set; } = true;
    public double MaxAllowedDbCeiling { get; set; } = 38.5;
    public double ThermalSafetyOverrideTempC { get; set; } = 84.0;
    public List<PredictiveRule> PredictiveRules { get; set; } = new();
}

public sealed record TelemetrySnapshot(
    DateTime TimestampUtc,
    SystemHardwareIdentity Identity,
    double DaemonRamMb,
    double CpuTempC,
    double CpuPowerWatts,
    double CpuClockMhz,
    double CpuTotalLoadPercent,
    double CpuMaxThreadLoadPercent,
    double CpuVoltageV,
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
    double MotherboardTempC,
    List<FanChannelTelemetry> FanChannels,
    LiquidCoolingStatus LiquidCooling,
    GpuGuardStatus GpuGuard,
    EnergyStatus Energy,
    string ActiveForegroundExe,
    PredictiveRule? ActivePredictiveRule,
    int PredictivePurgeRemainingSec,
    AcousticStatus Acoustic,
    BottleneckVerdict Bottleneck,
    FanProfileConfig ActiveFanConfig
);
