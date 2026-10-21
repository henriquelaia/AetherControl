using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using AetherControl.Daemon.Models;

namespace AetherControl.Daemon.Services;

// Manages modular telemetry and hardware integration plugins.
public sealed class PluginManagerService
{
    private readonly object _lock = new();
    private readonly List<AetherPluginInfo> _plugins;
    private readonly string _csvLogPath;
    private DateTime _lastCsvLogUtc = DateTime.MinValue;

    public PluginManagerService()
    {
        string appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string logDir = Path.Combine(appData, "AetherControl", "logs");
        try { Directory.CreateDirectory(logDir); } catch { }
        _csvLogPath = Path.Combine(logDir, "telemetry.csv");

        _plugins = new List<AetherPluginInfo>
        {
            new(
                Id: "thermal-rgb-sync",
                Name: "Thermal RGB Gradient Sync",
                Version: "1.2.0",
                Category: "Lighting",
                DescriptionPt: "Sincroniza a cor do LED/3D Digital Twin com a temperatura em tempo real (Azul → Âmbar → Vermelho).",
                DescriptionEn: "Synchronizes ARGB/3D Digital Twin lighting with live thermal load (Cool Blue → Amber → Red).",
                Enabled: true,
                StatusText: "Active · 60Hz Sync"
            ),
            new(
                Id: "csv-flight-recorder",
                Name: "Blackbox CSV Telemetry Logger",
                Version: "1.0.4",
                Category: "Diagnostics",
                DescriptionPt: "Grava histórico de temperaturas, consumo (W) e RPM em ficheiro CSV local a cada 2s.",
                DescriptionEn: "Records CPU/GPU temperatures, wattage, and fan RPM to a local CSV file every 2s.",
                Enabled: false,
                StatusText: "Standby"
            ),
            new(
                Id: "zero-power-idle-drop",
                Name: "Eco Idle Acoustic Drop",
                Version: "1.1.0",
                Category: "Efficiency",
                DescriptionPt: "Reduz a rotação da bomba e ventoinhas quando o consumo total baixa para repouso.",
                DescriptionEn: "Automatically lowers pump and chassis fan floor when system enters idle power state.",
                Enabled: true,
                StatusText: "Active · Eco Guard"
            ),
            new(
                Id: "osd-shared-memory",
                Name: "In-Game HUD Telemetry Bridge",
                Version: "0.9.8",
                Category: "Overlay",
                DescriptionPt: "Expõe métricas JSON ultra-rápidas para overlays de jogos e ecrãs secundários.",
                DescriptionEn: "Exposes low-latency telemetry stream for in-game overlays and secondary sensor panels.",
                Enabled: true,
                StatusText: "Listening :5175"
            )
        };
    }

    public IReadOnlyList<AetherPluginInfo> GetPlugins()
    {
        lock (_lock) return _plugins.ToList();
    }

    public IReadOnlyList<AetherPluginInfo> TogglePlugin(string id)
    {
        lock (_lock)
        {
            for (int i = 0; i < _plugins.Count; i++)
            {
                if (string.Equals(_plugins[i].Id, id, StringComparison.OrdinalIgnoreCase))
                {
                    bool nextState = !_plugins[i].Enabled;
                    string status = nextState ? "Active" : "Disabled";
                    _plugins[i] = _plugins[i] with { Enabled = nextState, StatusText = status };
                    break;
                }
            }
            return _plugins.ToList();
        }
    }

    public void OnTelemetryTick(TelemetrySnapshot snap)
    {
        lock (_lock)
        {
            var csvPlugin = _plugins.FirstOrDefault(p => p.Id == "csv-flight-recorder");
            if (csvPlugin is { Enabled: true } && (DateTime.UtcNow - _lastCsvLogUtc).TotalSeconds >= 2.0)
            {
                _lastCsvLogUtc = DateTime.UtcNow;
                try
                {
                    bool writeHeader = !File.Exists(_csvLogPath);
                    using var sw = new StreamWriter(_csvLogPath, append: true);
                    if (writeHeader)
                    {
                        sw.WriteLine("TimestampUtc,CpuTempC,CpuWatts,GpuTempC,GpuWatts,CoolantTempC,PumpRpm,TargetPwmPct");
                    }
                    double pwm = snap.FanChannels.Count > 1 ? snap.FanChannels[1].TargetPwmPercent : 0;
                    sw.WriteLine(string.Format(
                        CultureInfo.InvariantCulture,
                        "{0:O},{1:F1},{2:F1},{3:F1},{4:F1},{5:F1},{6:F0},{7:F1}",
                        snap.TimestampUtc,
                        snap.CpuTempC,
                        snap.CpuPowerWatts,
                        snap.GpuTempC,
                        snap.GpuPowerWatts,
                        snap.LiquidCooling.CoolantTempC,
                        snap.LiquidCooling.PumpRpm,
                        pwm));
                }
                catch { }
            }
        }
    }
}
