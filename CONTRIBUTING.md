# Contributing to AetherControl

Thank you for contributing to **AetherControl** ([https://github.com/henriquelaia/AetherControl](https://github.com/henriquelaia/AetherControl)). Our goal is to maintain a fast, low-overhead, hardware-agnostic thermal and fan control utility for Windows.

---

## Core Guidelines

1. **Zero External Runtime Dependencies:**
   - `AetherControl-NativeDaemon.ps1` compiles its native C# P/Invoke bridge (`AetherNativeBridgeV2`) in-memory using the built-in Windows .NET runtime so users can run the project immediately without installing extra SDKs.
2. **Hardware-Agnostic Discovery:**
   - Never hardcode specific CPU, GPU, or motherboard models in the frontend or backend. Always populate names and limits dynamically from `Invoke-HardwareTopologyScan` (`/api/hardware/scan` and `/api/telemetry`).
3. **Local-Only Security:**
   - The HTTP listener must bind strictly to `127.0.0.1` / `localhost`. Never add external telemetry, tracking, or outbound network calls.

---

## How to Contribute

### 1. Adding Motherboard Super I/O Mappings
In [`AetherControl-NativeDaemon.ps1`](AetherControl-NativeDaemon.ps1) inside `Invoke-HardwareTopologyScan`, you can expand the motherboard-to-Super-I/O mapping table (`ITE`, `Nuvoton`, `Fintek`) for additional AM4 / AM5 / LGA1700 / LGA1851 boards.

### 2. Adding Default Game / Workstation Profiles
In [`AetherControl-NativeDaemon.ps1`](AetherControl-NativeDaemon.ps1) and [`PredictiveCoolingWatchdog.cs`](src/AetherControl.Daemon/Services/PredictiveCoolingWatchdog.cs), you can add common game or workstation executables (`UnrealEditor.exe`, `DaVinciResolve.exe`, `cs2.exe`, etc.) with appropriate pre-cooling PWM floors.

### 3. Adding Translations (i18n)
In [`src/AetherControl.Daemon/wwwroot/app.js`](src/AetherControl.Daemon/wwwroot/app.js), the `i18n` object supports `pt-PT` and `en`. Additional locales (`es`, `fr`, `de`, `pt-BR`) can be added using the same key structure.

---

## Local Testing

1. Test live sensor polling in terminal mode:
   ```powershell
   .\Run-GPU-PoC-Only.bat
   ```
2. Verify hardware topology JSON output:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\AetherControl-NativeDaemon.ps1 -ScanOnly
   ```
3. Launch the application UI:
   ```powershell
   .\Launch-AetherControl.bat
   ```
