using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using AetherControl.Daemon.Models;

namespace AetherControl.Daemon.Services;

// Foreground process monitor for predictive cooling profiles.
public sealed class PredictiveCoolingWatchdog
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

    private readonly ConcurrentDictionary<string, PredictiveRule> _rules = new(StringComparer.OrdinalIgnoreCase);
    private readonly ConcurrentDictionary<uint, PredictiveRule> _activeTrackedPids = new();

    private PredictiveRule? _lastActiveRule;
    private DateTime _purgeUntilUtc = DateTime.MinValue;

    public string CurrentForegroundExe { get; private set; } = "explorer.exe";
    public PredictiveRule? ActiveRule { get; private set; }
    public int PurgeRemainingSeconds => Math.Max(0, (int)Math.Ceiling((_purgeUntilUtc - DateTime.UtcNow).TotalSeconds));

    public PredictiveCoolingWatchdog()
    {
        AddOrUpdateRule(new("Cyberpunk2077.exe", "Cyberpunk 2077", "Predictive Gaming", 58, 30));
        AddOrUpdateRule(new("cs2.exe", "Counter-Strike 2", "Predictive Gaming", 52, 20));
        AddOrUpdateRule(new("eldenring.exe", "Elden Ring", "Predictive Gaming", 55, 25));
        AddOrUpdateRule(new("FortniteClient-Win64-Shipping.exe", "Fortnite", "Predictive Gaming", 55, 25));
        AddOrUpdateRule(new("blender.exe", "Blender 3D Render", "Heavy Compute", 65, 35));
        AddOrUpdateRule(new("Cinebench.exe", "Cinebench Thermal Stress", "Max Cooling", 85, 40));
        AddOrUpdateRule(new("UnrealEditor.exe", "Unreal Engine 5 Editor", "Heavy Compute", 60, 30));
    }

    public IReadOnlyList<PredictiveRule> GetRules() => _rules.Values.OrderBy(r => r.DisplayName).ToList();

    public void AddOrUpdateRule(PredictiveRule rule)
    {
        string cleanExe = rule.ExecutableName.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)
            ? rule.ExecutableName
            : rule.ExecutableName + ".exe";
        _rules[cleanExe] = rule with { ExecutableName = cleanExe };
    }

    public bool RemoveRule(string exeName) => _rules.TryRemove(exeName, out _);

    public void ReplaceAllRules(IEnumerable<PredictiveRule> rules)
    {
        _rules.Clear();
        foreach (var r in rules)
        {
            if (r is not null && !string.IsNullOrWhiteSpace(r.ExecutableName))
            {
                AddOrUpdateRule(r);
            }
        }
    }

    public void EvaluateState()
    {
        IntPtr hwnd = GetForegroundWindow();
        if (hwnd != IntPtr.Zero)
        {
            GetWindowThreadProcessId(hwnd, out uint pid);
            if (pid != 0)
            {
                string? exe = TryGetProcessExecutableName(pid);
                if (!string.IsNullOrWhiteSpace(exe))
                {
                    CurrentForegroundExe = exe;
                    if (_rules.TryGetValue(exe, out var matchedRule))
                    {
                        _activeTrackedPids[pid] = matchedRule;
                        _lastActiveRule = matchedRule;
                        ActiveRule = matchedRule;
                        _purgeUntilUtc = DateTime.MinValue;
                        return;
                    }
                }
            }
        }

        // Prune any tracked background game PIDs that have exited (Alt-Tab resilience!)
        foreach (var kvp in _activeTrackedPids.ToArray())
        {
            if (!IsProcessAlive(kvp.Key))
            {
                _activeTrackedPids.TryRemove(kvp.Key, out var exitedRule);
                if (_activeTrackedPids.IsEmpty && exitedRule is not null)
                {
                    _purgeUntilUtc = DateTime.UtcNow.AddSeconds(exitedRule.CooldownPurgeSeconds);
                }
            }
            else if (_rules.TryGetValue(kvp.Value.ExecutableName, out var updatedRule))
            {
                _activeTrackedPids[kvp.Key] = updatedRule;
            }
        }

        if (!_activeTrackedPids.IsEmpty)
        {
            ActiveRule = _activeTrackedPids.Values
                .OrderByDescending(r => r.PreChargePwmFloorPercent)
                .First();
            _lastActiveRule = ActiveRule;
        }
        else if (DateTime.UtcNow < _purgeUntilUtc && _lastActiveRule is not null)
        {
            ActiveRule = _lastActiveRule;
        }
        else
        {
            ActiveRule = null;
        }
    }

    public IReadOnlyList<string> GetRunningWindowExecutables()
    {
        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        try
        {
            foreach (var p in Process.GetProcesses())
            {
                try
                {
                    if (p.MainWindowHandle != IntPtr.Zero && !string.IsNullOrWhiteSpace(p.ProcessName))
                    {
                        result.Add(p.ProcessName + ".exe");
                    }
                }
                catch { }
                finally { p.Dispose(); }
            }
        }
        catch { }
        return result.OrderBy(x => x).ToList();
    }

    private static bool IsProcessAlive(uint pid)
    {
        IntPtr hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
        if (hProc == IntPtr.Zero) return false;
        CloseHandle(hProc);
        return true;
    }

    private static string? TryGetProcessExecutableName(uint pid)
    {
        IntPtr hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
        if (hProc == IntPtr.Zero) return null;
        try
        {
            var sb = new StringBuilder(512);
            int capacity = sb.Capacity;
            if (QueryFullProcessImageName(hProc, 0, sb, ref capacity))
            {
                return Path.GetFileName(sb.ToString());
            }
            return null;
        }
        finally
        {
            CloseHandle(hProc);
        }
    }
}
