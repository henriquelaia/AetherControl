using System;
using System.Collections.Generic;
using System.Linq;
using AetherControl.Daemon.Hardware;
using AetherControl.Daemon.Models;

namespace AetherControl.Daemon.Services;

// Provides downloadable community-tested fan curves and one-click profile application.
public sealed class CommunityProfileService
{
    private readonly List<CommunityProfile> _profiles = new()
    {
        new(
            Id: "aio-360-liquid-equilibrium",
            Name: "HydroLoop 360mm Equilibrium",
            Author: "thermal_lab",
            Category: "AIO Liquid",
            DescriptionPt: "Guiado pela temperatura da água para eliminar picos de ruído em CPUs modernos.",
            DescriptionEn: "Guided by liquid coolant temperature to eliminate fan spikes on modern CPUs.",
            Stars: 428,
            TargetNoiseDb: 34.5,
            TemperatureSource: "LIQUID_COOLANT",
            HysteresisDeadbandC: 2.0,
            RecommendedPumpMode: "Balanced",
            CurvePoints: new() { new(25, 22), new(42, 30), new(58, 46), new(72, 68), new(84, 95) }
        ),
        new(
            Id: "noctua-whisper-sff",
            Name: "Whisper SFF Zero-Resonance",
            Author: "sff_acoustics",
            Category: "Ultra-Silent",
            DescriptionPt: "Curva sub-33 dBA otimizada para caixas compactas e trabalho noturno.",
            DescriptionEn: "Sub-33 dBA curve tuned for small form factor cases and quiet studio work.",
            Stars: 319,
            TargetNoiseDb: 32.8,
            TemperatureSource: "MAX_CPU_GPU",
            HysteresisDeadbandC: 4.0,
            RecommendedPumpMode: "Silent",
            CurvePoints: new() { new(30, 18), new(52, 26), new(68, 40), new(80, 62), new(88, 90) }
        ),
        new(
            Id: "esports-low-latency-boost",
            Name: "Competitive 240Hz Boost Lock",
            Author: "frametime_pro",
            Category: "Esports",
            DescriptionPt: "Mantém o GPU abaixo de 65°C para sustentar o clock Boost máximo sem quebras.",
            DescriptionEn: "Keeps GPU below 65°C to sustain peak frequency clocks without thermal drop.",
            Stars: 276,
            TargetNoiseDb: 41.0,
            TemperatureSource: "GPU",
            HysteresisDeadbandC: 2.0,
            RecommendedPumpMode: "Extreme",
            CurvePoints: new() { new(30, 42), new(48, 58), new(62, 76), new(72, 92), new(80, 100) }
        ),
        new(
            Id: "workstation-render-sustained",
            Name: "Workstation 24/7 Render Node",
            Author: "compute_ops",
            Category: "Workstation",
            DescriptionPt: "Rampa linear progressiva para cargas contínuas de Blender, Unreal e compilação.",
            DescriptionEn: "Progressive linear ramp for continuous Blender, Unreal, and code compilation loads.",
            Stars: 194,
            TargetNoiseDb: 39.5,
            TemperatureSource: "MAX_CPU_GPU",
            HysteresisDeadbandC: 2.5,
            RecommendedPumpMode: "Extreme",
            CurvePoints: new() { new(30, 35), new(45, 50), new(60, 68), new(74, 86), new(82, 100) }
        )
    };

    public IReadOnlyList<CommunityProfile> GetProfiles() => _profiles;

    public CommunityProfile? ApplyProfile(string id, HardwareMonitorService hardware, AcousticBalanceEngine acoustic)
    {
        var profile = _profiles.FirstOrDefault(p => string.Equals(p.Id, id, StringComparison.OrdinalIgnoreCase));
        if (profile is null) return null;

        hardware.UpdateFanConfig(new FanProfileConfig
        {
            ActivePreset = profile.Name,
            TemperatureSource = profile.TemperatureSource,
            HysteresisDeadbandC = profile.HysteresisDeadbandC,
            ManualOverrideEnabled = false,
            ManualOverridePercent = 50.0,
            CurvePoints = profile.CurvePoints.ToList()
        });

        hardware.PumpMode = profile.RecommendedPumpMode;
        hardware.RadiatorFanSyncToCoolant = string.Equals(profile.TemperatureSource, "LIQUID_COOLANT", StringComparison.OrdinalIgnoreCase);
        acoustic.MaxAllowedDbCeiling = profile.TargetNoiseDb;

        return profile;
    }
}
