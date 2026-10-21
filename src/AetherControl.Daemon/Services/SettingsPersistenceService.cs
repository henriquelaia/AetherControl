using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using AetherControl.Daemon.Hardware;
using AetherControl.Daemon.Models;

namespace AetherControl.Daemon.Services;

// Persists user fan curves, pump settings, acoustic limits, and game rules in %LOCALAPPDATA%\AetherControl.
public sealed class SettingsPersistenceService
{
    private readonly string _settingsFilePath;
    private readonly object _fileLock = new();
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    public SettingsPersistenceService()
    {
        string appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string dir = Path.Combine(appData, "AetherControl");
        try { Directory.CreateDirectory(dir); } catch { }
        _settingsFilePath = Path.Combine(dir, "settings.json");
    }

    public void LoadInto(HardwareMonitorService hardware, PredictiveCoolingWatchdog watchdog, AcousticBalanceEngine acoustic)
    {
        lock (_fileLock)
        {
            if (!File.Exists(_settingsFilePath)) return;
            try
            {
                string json = File.ReadAllText(_settingsFilePath);
                var state = JsonSerializer.Deserialize<PersistedUserSettings>(json, JsonOpts);
                if (state is not null)
                {
                    ApplyState(state, hardware, watchdog, acoustic);
                }
            }
            catch { }
        }
    }

    public void SaveFrom(HardwareMonitorService hardware, PredictiveCoolingWatchdog watchdog, AcousticBalanceEngine acoustic)
    {
        lock (_fileLock)
        {
            try
            {
                var state = ExtractState(hardware, watchdog, acoustic);
                string json = JsonSerializer.Serialize(state, JsonOpts);
                File.WriteAllText(_settingsFilePath, json);
            }
            catch { }
        }
    }

    public PersistedUserSettings ExtractState(HardwareMonitorService hardware, PredictiveCoolingWatchdog watchdog, AcousticBalanceEngine acoustic)
    {
        return new PersistedUserSettings
        {
            FanConfig = hardware.GetFanConfig(),
            PumpMode = hardware.PumpMode,
            RadiatorFanSyncToCoolant = hardware.RadiatorFanSyncToCoolant,
            AntiZeroRpmChatterEnabled = hardware.AntiZeroRpmChatterEnabled,
            MinimumActiveFanFloorPct = hardware.MinimumActiveFanFloorPct,
            AcousticEnabled = acoustic.Enabled,
            MaxAllowedDbCeiling = acoustic.MaxAllowedDbCeiling,
            ThermalSafetyOverrideTempC = acoustic.ThermalSafetyOverrideTempC,
            PredictiveRules = watchdog.GetRules().ToList()
        };
    }

    public void ApplyState(PersistedUserSettings state, HardwareMonitorService hardware, PredictiveCoolingWatchdog watchdog, AcousticBalanceEngine acoustic)
    {
        if (state.FanConfig is not null)
        {
            hardware.UpdateFanConfig(state.FanConfig);
        }

        if (!string.IsNullOrWhiteSpace(state.PumpMode))
        {
            hardware.PumpMode = state.PumpMode;
        }

        hardware.RadiatorFanSyncToCoolant = state.RadiatorFanSyncToCoolant;
        hardware.AntiZeroRpmChatterEnabled = state.AntiZeroRpmChatterEnabled;
        if (state.MinimumActiveFanFloorPct >= 20 && state.MinimumActiveFanFloorPct <= 80)
        {
            hardware.MinimumActiveFanFloorPct = state.MinimumActiveFanFloorPct;
        }

        acoustic.Enabled = state.AcousticEnabled;
        if (state.MaxAllowedDbCeiling >= 28 && state.MaxAllowedDbCeiling <= 55)
        {
            acoustic.MaxAllowedDbCeiling = state.MaxAllowedDbCeiling;
        }
        if (state.ThermalSafetyOverrideTempC >= 65 && state.ThermalSafetyOverrideTempC <= 95)
        {
            acoustic.ThermalSafetyOverrideTempC = state.ThermalSafetyOverrideTempC;
        }

        if (state.PredictiveRules is { Count: > 0 })
        {
            watchdog.ReplaceAllRules(state.PredictiveRules);
        }
    }
}
