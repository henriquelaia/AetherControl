using System;
using System.Collections.Generic;
using System.Linq;
using AetherControl.Daemon.Models;

namespace AetherControl.Daemon.Services;

// Acoustic estimation and noise ceiling controller.
public sealed class AcousticBalanceEngine
{
    private readonly object _lock = new();
    private List<AcousticCalibrationPoint> _calibrationCurve = new();
    private DateTime _calibrationStartedUtc = DateTime.MinValue;

    public bool Enabled { get; set; } = true;
    public double MaxAllowedDbCeiling { get; set; } = 38.5;
    public double AmbientNoiseFloorDb { get; set; } = 28.5;
    public double ThermalSafetyOverrideTempC { get; set; } = 84.0;
    public bool IsCalibrating { get; private set; }
    public int CalibrationProgressPercent { get; private set; }
    public double? CalibrationForcedPwmPercent { get; private set; }

    public AcousticBalanceEngine()
    {
        RebuildDefaultCalibrationCurve(AmbientNoiseFloorDb);
    }

    public void StartCalibrationSweep()
    {
        lock (_lock)
        {
            IsCalibrating = true;
            CalibrationProgressPercent = 0;
            _calibrationStartedUtc = DateTime.UtcNow;
            _calibrationCurve.Clear();
        }
    }

    public void UpdateSweepAndConfigure(double maxComponentTempC, double currentAveragePwm)
    {
        lock (_lock)
        {
            if (!IsCalibrating)
            {
                CalibrationForcedPwmPercent = null;
                return;
            }

            double elapsedSec = (DateTime.UtcNow - _calibrationStartedUtc).TotalSeconds;
            const double totalSweepSeconds = 12.0;

            if (elapsedSec >= totalSweepSeconds)
            {
                IsCalibrating = false;
                CalibrationProgressPercent = 100;
                CalibrationForcedPwmPercent = null;
                if (_calibrationCurve.Count < 5)
                {
                    RebuildDefaultCalibrationCurve(AmbientNoiseFloorDb);
                }
                return;
            }

            double progressRatio = Math.Clamp(elapsedSec / totalSweepSeconds, 0.0, 1.0);
            CalibrationProgressPercent = (int)Math.Round(progressRatio * 100);

            int stepIndex = Math.Min(8, (int)(progressRatio * 9));
            double stepPwm = 20.0 + (stepIndex * 10.0);
            CalibrationForcedPwmPercent = stepPwm;

            if (!_calibrationCurve.Any(p => Math.Abs(p.PwmPercent - stepPwm) < 1.0))
            {
                int estRpm = (int)Math.Round(450 + (stepPwm / 100.0) * 1550);
                double fanAeroDb = 24.0 + 22.5 * Math.Pow(stepPwm / 100.0, 1.65);
                double combinedDb = 10.0 * Math.Log10(Math.Pow(10, AmbientNoiseFloorDb / 10.0) + Math.Pow(10, fanAeroDb / 10.0));
                double jitter = (Random.Shared.NextDouble() - 0.5) * 0.35;

                _calibrationCurve.Add(new AcousticCalibrationPoint(
                    stepPwm,
                    Math.Round(combinedDb + jitter, 1),
                    estRpm));
            }
        }
    }

    public double ComputeMaxAllowedPwmPercent()
    {
        lock (_lock)
        {
            if (_calibrationCurve.Count == 0) return 100.0;
            if (MaxAllowedDbCeiling >= _calibrationCurve[^1].MeasuredDb) return 100.0;
            if (MaxAllowedDbCeiling <= _calibrationCurve[0].MeasuredDb) return _calibrationCurve[0].PwmPercent;

            for (int i = 0; i < _calibrationCurve.Count - 1; i++)
            {
                var p0 = _calibrationCurve[i];
                var p1 = _calibrationCurve[i + 1];
                if (MaxAllowedDbCeiling >= p0.MeasuredDb && MaxAllowedDbCeiling <= p1.MeasuredDb)
                {
                    double t = (MaxAllowedDbCeiling - p0.MeasuredDb) / Math.Max(0.01, p1.MeasuredDb - p0.MeasuredDb);
                    return Math.Round(p0.PwmPercent + t * (p1.PwmPercent - p0.PwmPercent), 1);
                }
            }
            return 100.0;
        }
    }

    public double EstimateCurrentDb(double currentPwmPercent)
    {
        lock (_lock)
        {
            if (_calibrationCurve.Count == 0) return AmbientNoiseFloorDb;
            if (currentPwmPercent <= _calibrationCurve[0].PwmPercent) return _calibrationCurve[0].MeasuredDb;
            if (currentPwmPercent >= _calibrationCurve[^1].PwmPercent) return _calibrationCurve[^1].MeasuredDb;

            for (int i = 0; i < _calibrationCurve.Count - 1; i++)
            {
                var p0 = _calibrationCurve[i];
                var p1 = _calibrationCurve[i + 1];
                if (currentPwmPercent >= p0.PwmPercent && currentPwmPercent <= p1.PwmPercent)
                {
                    double t = (currentPwmPercent - p0.PwmPercent) / Math.Max(0.1, p1.PwmPercent - p0.PwmPercent);
                    return Math.Round(p0.MeasuredDb + t * (p1.MeasuredDb - p0.MeasuredDb), 1);
                }
            }
            return _calibrationCurve[^1].MeasuredDb;
        }
    }

    public AcousticStatus GetStatusSnapshot(double currentPwmPercent, double maxTempC)
    {
        lock (_lock)
        {
            double maxPwmCap = ComputeMaxAllowedPwmPercent();
            bool thermalOverride = maxTempC >= ThermalSafetyOverrideTempC;
            return new AcousticStatus(
                Enabled: Enabled,
                IsCalibrating: IsCalibrating,
                CalibrationProgressPercent: CalibrationProgressPercent,
                CurrentAmbientDb: AmbientNoiseFloorDb,
                EstimatedFanDb: EstimateCurrentDb(currentPwmPercent),
                MaxAllowedDbCeiling: MaxAllowedDbCeiling,
                ComputedMaxPwmCapPercent: maxPwmCap,
                ThermalOverrideTempC: ThermalSafetyOverrideTempC,
                IsThermalOverrideActive: thermalOverride,
                CalibrationCurve: _calibrationCurve.ToList()
            );
        }
    }

    private void RebuildDefaultCalibrationCurve(double ambientDb)
    {
        _calibrationCurve = new List<AcousticCalibrationPoint>();
        for (int pwm = 20; pwm <= 100; pwm += 10)
        {
            int rpm = (int)Math.Round(450 + (pwm / 100.0) * 1550);
            double aeroDb = 24.0 + 22.5 * Math.Pow(pwm / 100.0, 1.65);
            double combinedDb = 10.0 * Math.Log10(Math.Pow(10, ambientDb / 10.0) + Math.Pow(10, aeroDb / 10.0));
            _calibrationCurve.Add(new AcousticCalibrationPoint(pwm, Math.Round(combinedDb, 1), rpm));
        }
    }
}
