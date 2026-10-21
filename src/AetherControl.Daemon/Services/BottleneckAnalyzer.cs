using System;
using AetherControl.Daemon.Models;

namespace AetherControl.Daemon.Services;

// Evaluates CPU, GPU, VRAM, and thermal load balance using an exponential moving average.
public sealed class BottleneckAnalyzer
{
    private const double Alpha = 0.28;

    private double _emaCpuTotal;
    private double _emaCpuMaxThread;
    private double _emaGpuCore;
    private double _emaGpuPowerRatio;
    private double _emaVramRatio;
    private bool _initialized;

    public BottleneckVerdict Analyze(
        double cpuTempC,
        double cpuTotalLoad,
        double cpuMaxThreadLoad,
        double gpuTempC,
        double gpuCoreLoad,
        double gpuPowerWatts,
        double gpuPowerLimitWatts,
        double vramUsedMb,
        double vramTotalMb)
    {
        double powerRatio = gpuPowerLimitWatts > 10 ? (gpuPowerWatts / gpuPowerLimitWatts) * 100.0 : 0.0;
        double vramRatio = vramTotalMb > 64 ? (vramUsedMb / vramTotalMb) * 100.0 : 0.0;

        if (!_initialized)
        {
            _emaCpuTotal = cpuTotalLoad;
            _emaCpuMaxThread = cpuMaxThreadLoad;
            _emaGpuCore = gpuCoreLoad;
            _emaGpuPowerRatio = powerRatio;
            _emaVramRatio = vramRatio;
            _initialized = true;
        }
        else
        {
            _emaCpuTotal = Alpha * cpuTotalLoad + (1 - Alpha) * _emaCpuTotal;
            _emaCpuMaxThread = Alpha * cpuMaxThreadLoad + (1 - Alpha) * _emaCpuMaxThread;
            _emaGpuCore = Alpha * gpuCoreLoad + (1 - Alpha) * _emaGpuCore;
            _emaGpuPowerRatio = Alpha * powerRatio + (1 - Alpha) * _emaGpuPowerRatio;
            _emaVramRatio = Alpha * vramRatio + (1 - Alpha) * _emaVramRatio;
        }

        if (cpuTempC >= 94.0 || gpuTempC >= 87.0)
        {
            return new BottleneckVerdict(
                Code: "THERMAL",
                PrimaryLimiter: "THERMAL THROTTLING ACTIVE",
                SeverityColor: "rose",
                ConfidencePercent: 98,
                TechnicalSummary: $"Thermal junction limit approached (CPU {cpuTempC:F0}°C / GPU {gpuTempC:F0}°C). Boost clocks are down-binning.",
                Recommendation: "Increase fan curve slope above 75°C or disable Acoustic Ceiling Cap immediately.",
                CpuPackageLoadPercent: Math.Round(_emaCpuTotal, 1),
                CpuFastestThreadPercent: Math.Round(_emaCpuMaxThread, 1),
                GpuCoreLoadPercent: Math.Round(_emaGpuCore, 1),
                GpuPowerLimitUsagePercent: Math.Round(_emaGpuPowerRatio, 1),
                VramUsagePercent: Math.Round(_emaVramRatio, 1)
            );
        }

        if (_emaGpuCore >= 94.0 && _emaCpuMaxThread < 88.0)
        {
            return new BottleneckVerdict(
                Code: "GPU_BOUND",
                PrimaryLimiter: "GPU CORE / SHADER BOUND (OPTIMAL)",
                SeverityColor: "cyan",
                ConfidencePercent: 95,
                TechnicalSummary: $"GPU execution units saturated at {_emaGpuCore:F1}% while fastest CPU thread has headroom ({_emaCpuMaxThread:F1}%).",
                Recommendation: "Ideal gaming balance. Enable DLSS/FSR Quality if higher framerate is desired.",
                CpuPackageLoadPercent: Math.Round(_emaCpuTotal, 1),
                CpuFastestThreadPercent: Math.Round(_emaCpuMaxThread, 1),
                GpuCoreLoadPercent: Math.Round(_emaGpuCore, 1),
                GpuPowerLimitUsagePercent: Math.Round(_emaGpuPowerRatio, 1),
                VramUsagePercent: Math.Round(_emaVramRatio, 1)
            );
        }

        if (_emaCpuMaxThread >= 90.0 && _emaGpuCore < 85.0)
        {
            return new BottleneckVerdict(
                Code: "CPU_SINGLE",
                PrimaryLimiter: "CPU SINGLE-THREAD / LOGIC BOUND",
                SeverityColor: "amber",
                ConfidencePercent: 89,
                TechnicalSummary: $"Fastest CPU logical core is saturated at {_emaCpuMaxThread:F1}% (Package avg {_emaCpuTotal:F1}%), starving GPU ({_emaGpuCore:F1}%).",
                Recommendation: "Main game/application thread is L3 cache or IPC limited. Reduce crowd density / draw distance.",
                CpuPackageLoadPercent: Math.Round(_emaCpuTotal, 1),
                CpuFastestThreadPercent: Math.Round(_emaCpuMaxThread, 1),
                GpuCoreLoadPercent: Math.Round(_emaGpuCore, 1),
                GpuPowerLimitUsagePercent: Math.Round(_emaGpuPowerRatio, 1),
                VramUsagePercent: Math.Round(_emaVramRatio, 1)
            );
        }

        return new BottleneckVerdict(
            Code: "BALANCED",
            PrimaryLimiter: "SYSTEM BALANCED // HEADROOM AVAILABLE",
            SeverityColor: "emerald",
            ConfidencePercent: 99,
            TechnicalSummary: $"No hardware subsystem saturated (CPU Peak Thread {_emaCpuMaxThread:F0}%, GPU Core {_emaGpuCore:F0}%, VRAM {_emaVramRatio:F0}%).",
            Recommendation: "System operating in high-efficiency acoustic window.",
            CpuPackageLoadPercent: Math.Round(_emaCpuTotal, 1),
            CpuFastestThreadPercent: Math.Round(_emaCpuMaxThread, 1),
            GpuCoreLoadPercent: Math.Round(_emaGpuCore, 1),
            GpuPowerLimitUsagePercent: Math.Round(_emaGpuPowerRatio, 1),
            VramUsagePercent: Math.Round(_emaVramRatio, 1)
        );
    }
}
