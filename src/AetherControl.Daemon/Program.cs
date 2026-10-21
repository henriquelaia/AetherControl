using System;
using System.Diagnostics;
using System.Linq;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using AetherControl.Daemon.Hardware;
using AetherControl.Daemon.Models;
using AetherControl.Daemon.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

var jsonOptions = new JsonSerializerOptions
{
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    WriteIndented = false
};

var watchdog = new PredictiveCoolingWatchdog();
var acoustic = new AcousticBalanceEngine();
var bottleneck = new BottleneckAnalyzer();
var persistence = new SettingsPersistenceService();
var community = new CommunityProfileService();
var plugins = new PluginManagerService();
using var hardware = new HardwareMonitorService(watchdog, acoustic, bottleneck);

persistence.LoadInto(hardware, watchdog, acoustic);

AppDomain.CurrentDomain.ProcessExit += (_, _) => hardware.RestoreBiosFanControl();
Console.CancelKeyPress += (_, _) => hardware.RestoreBiosFanControl();

var initialSnap = hardware.PollAndControl();
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("================================================================================");
Console.WriteLine("  AETHERCONTROL // LOW-LEVEL HARDWARE TELEMETRY & PREDICTIVE COOLING DAEMON");
Console.WriteLine("================================================================================");
Console.ResetColor();
Console.WriteLine($"  CPU Detected         : {initialSnap.Identity.CpuName}");
Console.WriteLine($"  GPU Detected         : {initialSnap.Identity.GpuName}");
Console.WriteLine($"  GPU Telemetry Driver : {initialSnap.Identity.GpuBackendDriver}");
Console.WriteLine($"  Motherboard          : {initialSnap.Identity.MotherboardName} ({hardware.SuperIoChip})");
Console.WriteLine($"  Memory & Storage     : {hardware.TotalRamGb} GB ({hardware.RamSpeedMhz} MHz) | {hardware.PrimaryStorageName} ({hardware.PrimaryStorageTempC:F0}°C)");
Console.WriteLine($"  OS / Ring-0 Admin    : {initialSnap.Identity.OsDescription} (Admin={initialSnap.Identity.IsElevatedAdmin})");
Console.WriteLine("--------------------------------------------------------------------------------");
Console.ForegroundColor = ConsoleColor.Green;
Console.WriteLine($"  [LIVE SENSOR READOUT]");
Console.WriteLine($"  -> GPU Temp & Power  : {initialSnap.GpuTempC:F1} °C (Hotspot {initialSnap.GpuHotspotTempC:F1} °C) | {initialSnap.GpuPowerWatts:F2} W / {initialSnap.GpuPowerLimitWatts:F0} W");
Console.WriteLine($"  -> CPU Temp & Power  : {initialSnap.CpuTempC:F1} °C | {initialSnap.CpuPowerWatts:F1} W | {initialSnap.CpuClockMhz:F0} MHz");
Console.WriteLine($"  -> Bottleneck Engine : {initialSnap.Bottleneck.PrimaryLimiter}");
Console.WriteLine($"  -> Daemon Footprint  : {initialSnap.DaemonRamMb:F1} MB RAM");
Console.ResetColor();
Console.WriteLine("================================================================================\n");

if (args.Contains("--poc-only", StringComparer.OrdinalIgnoreCase))
{
    for (int i = 0; i < 5; i++)
    {
        var s = hardware.PollAndControl();
        Console.WriteLine(
            $"[{DateTime.Now:HH:mm:ss.fff}] GPU: {s.Identity.GpuName} | Temp: {s.GpuTempC:F1}°C | Power: {s.GpuPowerWatts:F2}W | " +
            $"CPU: {s.CpuTempC:F1}°C ({s.CpuPowerWatts:F1}W) | Active App: {s.ActiveForegroundExe} | Target PWM: {s.FanChannels[0].TargetPwmPercent:F1}%");
        await Task.Delay(500);
    }
    return;
}

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.WebHost.UseUrls("http://127.0.0.1:5175");

var app = builder.Build();
app.UseDefaultFiles();
app.UseStaticFiles();
app.UseWebSockets();

using var daemonCts = new CancellationTokenSource();
var backgroundLoop = Task.Run(async () =>
{
    using var timer = new PeriodicTimer(TimeSpan.FromMilliseconds(250));
    while (await timer.WaitForNextTickAsync(daemonCts.Token))
    {
        try
        {
            var snap = hardware.PollAndControl();
            plugins.OnTelemetryTick(snap);
        }
        catch { }
    }
}, daemonCts.Token);

app.Map("/ws/telemetry", async (HttpContext context) =>
{
    if (!context.WebSockets.IsWebSocketRequest)
    {
        context.Response.StatusCode = 400;
        return;
    }

    using var ws = await context.WebSockets.AcceptWebSocketAsync();
    using var timer = new PeriodicTimer(TimeSpan.FromMilliseconds(250));
    try
    {
        while (ws.State == WebSocketState.Open && await timer.WaitForNextTickAsync(context.RequestAborted))
        {
            var snap = hardware.LatestSnapshot ?? hardware.PollAndControl();
            byte[] payload = JsonSerializer.SerializeToUtf8Bytes(snap, jsonOptions);
            await ws.SendAsync(payload, WebSocketMessageType.Text, true, context.RequestAborted);
        }
    }
    catch { }
});

app.MapGet("/api/telemetry", () => Results.Json(hardware.LatestSnapshot ?? hardware.PollAndControl(), jsonOptions));

app.MapPost("/api/fan/preset/{preset}", (string preset) =>
{
    hardware.ApplyPreset(preset);
    persistence.SaveFrom(hardware, watchdog, acoustic);
    return Results.Json(hardware.GetFanConfig(), jsonOptions);
});

app.MapPost("/api/fan/config", async (HttpContext ctx) =>
{
    var cfg = await JsonSerializer.DeserializeAsync<FanProfileConfig>(ctx.Request.Body, jsonOptions);
    if (cfg is not null)
    {
        hardware.UpdateFanConfig(cfg);
        persistence.SaveFrom(hardware, watchdog, acoustic);
    }
    return Results.Json(hardware.GetFanConfig(), jsonOptions);
});

app.MapPost("/api/fan/identify/{id}", (string id) =>
{
    hardware.IdentifyFanChannel(id);
    return Results.Json(new { identified = id, durationSeconds = 3.5 }, jsonOptions);
});

app.MapGet("/api/predictive/rules", () => Results.Json(watchdog.GetRules(), jsonOptions));
app.MapGet("/api/predictive/running-apps", () => Results.Json(watchdog.GetRunningWindowExecutables(), jsonOptions));

app.MapPost("/api/predictive/rules", async (HttpContext ctx) =>
{
    var rule = await JsonSerializer.DeserializeAsync<PredictiveRule>(ctx.Request.Body, jsonOptions);
    if (rule is not null && !string.IsNullOrWhiteSpace(rule.ExecutableName))
    {
        watchdog.AddOrUpdateRule(rule);
        persistence.SaveFrom(hardware, watchdog, acoustic);
    }
    return Results.Json(watchdog.GetRules(), jsonOptions);
});

app.MapDelete("/api/predictive/rules/{exeName}", (string exeName) =>
{
    watchdog.RemoveRule(exeName);
    persistence.SaveFrom(hardware, watchdog, acoustic);
    return Results.Json(watchdog.GetRules(), jsonOptions);
});

app.MapPost("/api/acoustic/config", async (HttpContext ctx) =>
{
    using var doc = await JsonDocument.ParseAsync(ctx.Request.Body);
    var root = doc.RootElement;
    if (root.TryGetProperty("enabled", out var en)) acoustic.Enabled = en.GetBoolean();
    if (root.TryGetProperty("maxAllowedDbCeiling", out var db)) acoustic.MaxAllowedDbCeiling = db.GetDouble();
    if (root.TryGetProperty("thermalOverrideTempC", out var th)) acoustic.ThermalSafetyOverrideTempC = th.GetDouble();
    persistence.SaveFrom(hardware, watchdog, acoustic);
    return Results.Ok();
});

app.MapPost("/api/acoustic/calibrate", () =>
{
    acoustic.StartCalibrationSweep();
    return Results.Ok();
});

app.MapPost("/api/liquid/config", async (HttpContext ctx) =>
{
    using var doc = await JsonDocument.ParseAsync(ctx.Request.Body);
    var root = doc.RootElement;
    if (root.TryGetProperty("pumpMode", out var pm) && pm.GetString() is string mode) hardware.PumpMode = mode;
    if (root.TryGetProperty("radiatorFanSyncToCoolant", out var sync)) hardware.RadiatorFanSyncToCoolant = sync.GetBoolean();
    if (root.TryGetProperty("triggerAntiAirlockPulse", out var pulse) && pulse.GetBoolean()) hardware.TriggerAirlockPulse();
    persistence.SaveFrom(hardware, watchdog, acoustic);
    return Results.Ok();
});

app.MapPost("/api/gpuguard/config", async (HttpContext ctx) =>
{
    using var doc = await JsonDocument.ParseAsync(ctx.Request.Body);
    var root = doc.RootElement;
    if (root.TryGetProperty("antiZeroRpmChatterEnabled", out var en)) hardware.AntiZeroRpmChatterEnabled = en.GetBoolean();
    if (root.TryGetProperty("minimumActiveFanFloorPct", out var fl)) hardware.MinimumActiveFanFloorPct = fl.GetDouble();
    persistence.SaveFrom(hardware, watchdog, acoustic);
    return Results.Ok();
});

app.MapGet("/api/profile/export", () =>
{
    var state = persistence.ExtractState(hardware, watchdog, acoustic);
    return Results.Json(state, jsonOptions);
});

app.MapGet("/api/community/profiles", () =>
{
    return Results.Json(community.GetProfiles(), jsonOptions);
});

app.MapPost("/api/community/profiles/apply/{id}", (string id) =>
{
    var applied = community.ApplyProfile(id, hardware, acoustic);
    if (applied is null) return Results.NotFound();
    persistence.SaveFrom(hardware, watchdog, acoustic);
    return Results.Json(new { applied = applied.Name, fanConfig = hardware.GetFanConfig() }, jsonOptions);
});

app.MapGet("/api/plugins", () =>
{
    return Results.Json(plugins.GetPlugins(), jsonOptions);
});

app.MapPost("/api/plugins/toggle/{id}", (string id) =>
{
    return Results.Json(plugins.TogglePlugin(id), jsonOptions);
});

app.MapPost("/api/profile/import", async (HttpContext ctx) =>
{
    var state = await JsonSerializer.DeserializeAsync<PersistedUserSettings>(ctx.Request.Body, jsonOptions);
    if (state is null) return Results.BadRequest();
    persistence.ApplyState(state, hardware, watchdog, acoustic);
    persistence.SaveFrom(hardware, watchdog, acoustic);
    return Results.Json(hardware.GetFanConfig(), jsonOptions);
});

app.MapGet("/api/system/startup", () =>
{
    return Results.Json(new { enabled = StartupTaskManager.IsStartupEnabled() }, jsonOptions);
});

app.MapPost("/api/system/startup", async (HttpContext ctx) =>
{
    using var doc = await JsonDocument.ParseAsync(ctx.Request.Body);
    bool target = doc.RootElement.TryGetProperty("enabled", out var en) && en.GetBoolean();
    bool ok = StartupTaskManager.SetStartupEnabled(target);
    return Results.Json(new { success = ok, enabled = StartupTaskManager.IsStartupEnabled() }, jsonOptions);
});

app.MapGet("/api/hardware/scan", () =>
{
    var s = hardware.LatestSnapshot ?? hardware.PollAndControl();
    return Results.Json(new
    {
        cpu = new { name = s.Identity.CpuName, cores = Math.Max(1, Environment.ProcessorCount / 2), threads = Environment.ProcessorCount, maxClockMhz = s.CpuClockMhz },
        gpu = new { name = s.Identity.GpuName, vramMb = s.GpuVramTotalMb, driver = s.Identity.GpuBackendDriver },
        motherboard = new { name = s.Identity.MotherboardName, superIoChip = hardware.SuperIoChip, biosVersion = hardware.BiosVersion },
        cooling = new { controller = s.LiquidCooling.ControllerName, fanCount = s.FanChannels.Count },
        memory = new { totalGb = hardware.TotalRamGb, speedMhz = hardware.RamSpeedMhz },
        storage = new { name = hardware.PrimaryStorageName, tempC = hardware.PrimaryStorageTempC },
        os = new { caption = s.Identity.OsDescription, isAdmin = s.Identity.IsElevatedAdmin, startupEnabled = StartupTaskManager.IsStartupEnabled() }
    }, jsonOptions);
});

app.MapPost("/api/daemon/shutdown", () =>
{
    hardware.RestoreBiosFanControl();
    daemonCts.Cancel();
    _ = Task.Run(async () => { await Task.Delay(200); Environment.Exit(0); });
    return Results.Json(new { status = "shutting_down" }, jsonOptions);
});

Console.ForegroundColor = ConsoleColor.Yellow;
Console.WriteLine("  [*] Control Center UI Live at : http://127.0.0.1:5175");
Console.WriteLine("  [*] Closing the UI window uses 0.0 MB RAM while Daemon keeps protecting hardware.");
Console.WriteLine("  [*] Press Ctrl+C to stop daemon and restore BIOS fan control.\n");
Console.ResetColor();

if (!args.Contains("--no-browser", StringComparer.OrdinalIgnoreCase))
{
    _ = Task.Run(async () =>
    {
        await Task.Delay(900);
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "msedge",
                Arguments = "--app=http://127.0.0.1:5175 --window-size=1420,900",
                UseShellExecute = true
            });
        }
        catch
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "http://127.0.0.1:5175",
                    UseShellExecute = true
                });
            }
            catch { }
        }
    });
}

await app.RunAsync();
daemonCts.Cancel();
