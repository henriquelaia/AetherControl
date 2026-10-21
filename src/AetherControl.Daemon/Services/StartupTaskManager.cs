using System;
using System.Diagnostics;
using System.IO;

namespace AetherControl.Daemon.Services;

// Manages Windows Task Scheduler registration for starting AetherControl at user logon.
public static class StartupTaskManager
{
    private const string TaskName = "AetherControlDaemon";

    public static bool IsStartupEnabled()
    {
        try
        {
            using var proc = Process.Start(new ProcessStartInfo
            {
                FileName = "schtasks.exe",
                Arguments = $"/Query /TN \"{TaskName}\"",
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            });
            proc?.WaitForExit(2000);
            return proc?.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }

    public static bool SetStartupEnabled(bool enable)
    {
        try
        {
            if (!enable)
            {
                using var delProc = Process.Start(new ProcessStartInfo
                {
                    FileName = "schtasks.exe",
                    Arguments = $"/Delete /TN \"{TaskName}\" /F",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                });
                delProc?.WaitForExit(3000);
                return true;
            }

            string exePath = Environment.ProcessPath ?? Path.Combine(AppContext.BaseDirectory, "AetherControl.Daemon.exe");
            string trCommand = $"\\\"{exePath}\\\" --no-browser";

            using var createProc = Process.Start(new ProcessStartInfo
            {
                FileName = "schtasks.exe",
                Arguments = $"/Create /TN \"{TaskName}\" /TR \"{trCommand}\" /SC ONLOGON /RL HIGHEST /F",
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            });
            createProc?.WaitForExit(3000);
            return createProc?.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }
}
