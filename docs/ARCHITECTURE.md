# AetherControl — System Architecture & Engineering Specification

This document describes the internal architecture of **AetherControl**, detailing how it performs low-overhead hardware telemetry, zero-dependency startup on Windows 10/11, and smooth thermal fan control.

---

## 1. End-to-End Architecture

```mermaid
flowchart TB
    subgraph Ring3["Ring-3 Native Win32 / C# Interop (AetherNativeBridgeV2)"]
        NVML["nvml.dll P/Invoke\n• Die Temp & Power (mW)\n• Core / Memory Clocks\n• Shader & VRAM Utilization"]
        K32["kernel32.dll\n• GetSystemTimes() CPU Delta\n• QueryFullProcessImageName()"]
        U32["user32.dll\n• GetForegroundWindow()\n• GetWindowThreadProcessId()"]
        CIM["SMBIOS / WMI CIM Discovery\n• Win32_Processor\n• Win32_BaseBoard & BIOS\n• Win32_PnPEntity (USB AIO)"]
    end

    subgraph Daemon["AetherControl Control Loop (250ms Tick)"]
        Scanner["Universal Hardware Auto-Scanner\n(Invoke-HardwareTopologyScan)"]
        Liquid["Coolant Thermal Inertia Solver\n(1st-Order Differential Lag)"]
        Watchdog["Predictive Process Watchdog\n(Pre-Ramps PWM on Game Launch)"]
        Hyst["Asymmetric Hysteresis & Spline Solver\n(Deadband + Acoustic dBA Cap)"]
        BN["Real-Time Bottleneck Classifier\n(CPU Thread vs GPU Core vs Thermal)"]
    end

    subgraph Frontend["UI Dashboard (http://127.0.0.1:5175)"]
        Bento["4-Card Telemetry Row + 2-Panel Control Studio"]
        CurveSVG["Interactive Cubic-Bezier SVG Fan Curve\nwith Live Beacon & 5-Point Coordinate Strip"]
        Theme["Light / Dark Theme Engine & PT-PT / EN Localization"]
    end

    NVML --> Daemon
    K32 --> Daemon
    U32 --> Daemon
    CIM --> Scanner
    Scanner --> Daemon
    Daemon <-->|"Local REST JSON API (127.0.0.1)"| Frontend
```

---

## 2. In-Memory C# Compilation

Traditional Windows hardware utilities require installing specific runtime bundles or heavy Electron frameworks.

**AetherControl** embeds `AetherNativeBridgeV2` (C# `[DllImport]` P/Invoke bindings for `nvml.dll`, `kernel32.dll`, and `user32.dll`) directly inside [`AetherControl-NativeDaemon.ps1`](../AetherControl-NativeDaemon.ps1) and compiles it into memory at startup via `Add-Type -Language CSharp`.

- **Startup Compilation Time:** `< 180 ms`
- **Memory Footprint:** `~45–85 MB`
- **Local-Only HTTP Server:** Binds strictly to `127.0.0.1:5175` (`localhost`) using `HttpListener.BeginGetContext` with a `200ms` wait handle so `Ctrl+C` and `/api/daemon/shutdown` exit cleanly.

---

## 3. Thermal Control Models

### 3.1 Asymmetric Hysteresis Deadband
To prevent rapid fan speed oscillation when CPU temperature spikes briefly during short workloads, AetherControl applies an asymmetric directional deadband $D_h$ (default `3.0 °C`):

$$T_{\text{eff}}(t) = \begin{cases} T_{\text{raw}}(t) & \text{if } T_{\text{raw}}(t) \ge T_{\text{eff}}(t-1) \quad \text{(Immediate step-up)} \\ T_{\text{raw}}(t) & \text{if } T_{\text{eff}}(t-1) - T_{\text{raw}}(t) \ge D_h \quad \text{(Delayed step-down)} \\ T_{\text{eff}}(t-1) & \text{otherwise} \end{cases}$$

### 3.2 Water Cooling (AIO) Thermal Inertia Model
Water has a high specific heat capacity ($4.184\text{ J/(g}\cdot^\circ\text{C)}$), warming and cooling much more gradually than a silicon die. AetherControl models steady-state coolant temperature $T_{\text{eq}}$ from total loop heat load and radiator airflow:

$$T_{\text{eq}} = T_{\text{ambient}} + 0.068 \cdot (P_{\text{CPU}} + 0.25 P_{\text{GPU}}) - 0.045 \cdot \text{PWM}_{\text{smooth}}$$

$$T_{\text{coolant}}(t) = T_{\text{coolant}}(t-1) + \alpha \cdot \left(T_{\text{eq}} - T_{\text{coolant}}(t-1)\right)$$

Enabling **Sync to water (`Guiar pela água`)** drives radiator fans from liquid temperature instead of short CPU spikes.

### 3.3 Acoustic Decibel Ceiling (`dBA`)
AetherControl maps target PWM % to estimated acoustic output ($\text{dBA}$) and enforces the configured `maxAllowedDbCeiling` (default `38.5 dBA`), unless silicon temperature reaches the safety cutoff (`84.0 °C`), where full cooling is automatically unlocked.

---

## 4. Local HTTP REST API Reference

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/api/telemetry` | `GET` | Returns real-time hardware telemetry, fan channels, water cooling status, bottleneck analysis, and energy cost. |
| `/api/hardware/scan` | `GET` | Runs or returns the hardware auto-scanner topology (`?refresh=1` forces a fresh scan). |
| `/api/fan/preset/{name}` | `POST` | Activates a curve preset (`Silent`, `Balanced`, `Predictive Gaming`, `Heavy Compute`, `Max Cooling`). |
| `/api/fan/config` | `POST` | Updates custom spline curve nodes, temperature source, hysteresis deadband, or manual PWM override. |
| `/api/liquid/config` | `POST` | Sets AIO pump mode (`Silent`, `Balanced`, `Extreme`), coolant sync, or triggers the 15s bubble purge. |
| `/api/gpuguard/config` | `POST` | Configures the GPU Zero-RPM Chatter Guard minimum active fan floor (%). |
| `/api/predictive/rules` | `GET / POST / DELETE` | Lists, adds, or deletes Win32 foreground application pre-cooling rules. |
| `/api/acoustic/config` | `POST` | Updates the maximum allowed decibel (`dBA`) ceiling. |
| `/api/fan/identify/{id}` | `POST` | Temporarily spins a specific fan header to 100% for 3.5 seconds to identify physical chassis fans. |
| `/api/profile/export` | `GET` | Exports complete user settings (curves, pump mode, acoustic ceiling, rules) as a shareable JSON file. |
| `/api/profile/import` | `POST` | Imports and applies a user settings JSON profile. |
| `/api/system/startup` | `GET / POST` | Checks or configures Windows Scheduled Task for silent start at user logon (`--no-browser`). |
| `/api/community/profiles` | `GET` | Returns catalog of community-tested thermal and acoustic fan profiles. |
| `/api/community/profiles/apply/{id}` | `POST` | One-click applies and persists a community fan profile. |
| `/api/plugins` | `GET` | Lists modular telemetry plugins and their live status. |
| `/api/plugins/toggle/{id}` | `POST` | Toggles plugin enabled state (e.g. CSV Flight Recorder, Thermal RGB Sync, OSD Bridge). |
| `/api/daemon/shutdown` | `POST` | Stops the daemon and restores fan control to motherboard BIOS/UEFI. |

---

## 5. 3D Digital Twin & Thermal Heatmap Architecture

The **3D Digital Twin** runs on a hardware-accelerated 2.5D/3D perspective projection pipeline with **zero garbage-collection memory allocations per frame**:

1. **Pre-Allocated Object & Streamline Buffers:** Particle arrays (`airflowPool`, `coolantPool`) and geometric coordinate sets are instantiated once during initialization and mutated in-place each frame.
2. **Thermal Heatmap Shader:** Dynamically maps live junction temperatures ($T$) to an RGB continuous gradient:
   $$\text{Color}(T) = \begin{cases} \text{Cryo Cyan } (\#06\text{B}6\text{D}4) & T \le 35^\circ\text{C} \\ \text{Nominal Emerald } (\#10\text{B}981) & 35^\circ\text{C} < T \le 55^\circ\text{C} \\ \text{Warm Amber } (\#\text{F}59\text{E}0\text{B}) & 55^\circ\text{C} < T \le 72^\circ\text{C} \\ \text{Critical Red } (\#\text{F}43\text{F}5\text{E}) & T > 72^\circ\text{C} \end{cases}$$
3. **Synchronized Angular Velocities:** 3D rotor blade rotations are directly coupled to real sensor tachometers:
   $$\omega_{\text{rotor}} = \frac{\text{RPM}}{60} \cdot 2\pi \cdot \Delta t$$
---

## 6. Execution Lifecycle & Data Flow Sequence

```mermaid
sequenceDiagram
    autonumber
    participant HW as Hardware Sensors (CPU/GPU/AIO)
    participant Bridge as C# Native Bridge (P/Invoke)
    participant Loop as Daemon Control Loop (250ms)
    participant API as REST HTTP Server (127.0.0.1)
    participant UI as Studio WebUI & 3D Twin

    loop Every 250ms
        Loop->>Bridge: QueryDieSensors()
        Bridge->>HW: nvmlDeviceGetTemperature(), GetSystemTimes()
        HW-->>Bridge: Raw metrics (die °C, clocks, watts, RPM)
        Bridge-->>Loop: Native C# Telemetry Struct
        Loop->>Loop: Evaluate Asymmetric Hysteresis
        Loop->>Loop: Compute Liquid Inertia & Acoustic Limit
        Loop->>Loop: Calculate Target PWM %
        Loop->>HW: Apply PWM via Super I/O / FanController
    end

    loop Every 800ms
        UI->>API: GET /api/telemetry
        API-->>UI: Telemetry JSON Snapshot
        UI->>UI: Update 4 Bento Metric Cards
        UI->>UI: Reposition Fan Curve Beacon & Glow
        UI->>UI: 60 FPS Digital Twin Thermal Plasma Update
    end

    opt User Customization
        UI->>API: POST /api/fan/config (Drag node P1-P5)
        API->>Loop: ApplySplineCurveNodes()
        Loop->>Loop: Persist to %LOCALAPPDATA%\AetherControl\settings.json
        API-->>UI: 200 OK Status
    end
```
