# AetherControl — Visual Architecture & Process Diagrams

This document contains comprehensive visual diagrams detailing the architecture, hardware telemetry loops, thermal state machine, and 3D digital twin rendering pipeline of **AetherControl**.

---

## 1. High-Level System Architecture

```mermaid
flowchart TB
    subgraph HW["Physical Hardware Layer"]
        CPU["CPU Package (AMD Zen / Intel Core)"]
        GPU["GPU Die (NVIDIA GeForce / AMD Radeon)"]
        MB["Motherboard Super I/O (Nuvoton / ITE)"]
        AIO["AIO Liquid Loop (Pump & Radiator)"]
        RAM["DDR4 / DDR5 Memory"]
    end

    subgraph OS["Windows 10 / 11 Kernel & User Mode (Ring-3)"]
        NVML["nvml.dll (Native GPU P/Invoke)"]
        K32["kernel32.dll (GetSystemTimes load)"]
        U32["user32.dll (Process Watchdog)"]
        CIM["WMI / CIM (SMBIOS & Hardware Scanner)"]
    end

    subgraph Core["AetherControl Core Daemon (250ms Loop)"]
        ScanEngine["Hardware Auto-Scanner"]
        HystEngine["Asymmetric Hysteresis Solver"]
        AioEngine["Coolant Inertia & Saturation Model"]
        Watchdog["Win32 Predictive Watchdog"]
        Safety["Thermal Override Guard (>85°C)"]
        Server["Local REST Server (127.0.0.1:5175)"]
    end

    subgraph UI["AetherControl Studio (Browser / App Mode)"]
        Bento["Bento-Box Telemetry Cards"]
        Curve["5-Point Spline Fan Curve Editor"]
        CAD["Solid CAD 3D Digital Twin"]
        Modal["Expanded Inspection Modal"]
        Eco["Community Profiles & Plugins"]
    end

    CPU --> K32
    GPU --> NVML
    MB --> CIM
    AIO --> CIM
    RAM --> CIM

    K32 --> ScanEngine
    NVML --> ScanEngine
    CIM --> ScanEngine
    U32 --> Watchdog

    ScanEngine --> HystEngine
    HystEngine --> AioEngine
    AioEngine --> Safety
    Safety --> Server

    Server <-->|"Sub-2ms JSON Telemetry"| Bento
    Server <-->|"Curve Parameters"| Curve
    Server <-->|"60 FPS Plasma Colors"| CAD
    Server <-->|"HUD Sensor Chips"| Modal
    Server <-->|"Profile Catalog"| Eco
```

---

## 2. Telemetry Ingestion & Fan Curve Lifecycle

```mermaid
sequenceDiagram
    autonumber
    participant Sensor as Hardware Sensor
    participant PInvoke as C# Native P/Invoke
    participant Controller as Thermal Controller
    participant Watchdog as Predictive Watchdog
    participant Hardware as Super I/O / PWM Bus
    participant Client as Dashboard UI (60 FPS)

    loop Every 250ms Telemetry Tick
        Sensor->>PInvoke: Read Temperature & Clocks
        PInvoke-->>Controller: Raw Ingest (°C, Watts, RPM)
        Watchdog->>Controller: Query Foreground Game State
        Controller->>Controller: Compute Asymmetric Hysteresis Deadband
        Controller->>Controller: Calculate Radiator Coolant Inertia
        alt Die Temp >= 85°C
            Controller->>Hardware: Force 100% Emergency Safety PWM
        else Normal Curve Operation
            Controller->>Hardware: Write Dynamic PWM Target
        end
    end

    loop Every 800ms UI Polling
        Client->>Controller: GET /api/telemetry
        Controller-->>Client: JSON Snapshot
        Client->>Client: Re-render Bento Metrics & 3D Twin Shaders
    end
```

---

## 3. Solid CAD 3D Digital Twin Rendering Pipeline

```mermaid
flowchart LR
    Sensors["Live Telemetry (°C, RPM)"] --> Plasma["Thermal Plasma Shader"]
    Sensors --> Rotor["Angular Velocity Solver"]
    
    subgraph Twin["3D Digital Twin Engine (Zero GC Allocation)"]
        Plasma --> MB_CAD["Solid Motherboard & DDR5 Glow"]
        Plasma --> CPU_CAD["AIO Waterblock Core Glow"]
        Plasma --> GPU_CAD["Solid GPU Shroud & Backplate"]
        Rotor --> Fan_CAD["Axial Blade Rotation (Live RPM)"]
        Air["Wind Tunnel Vectors"] --> Chassi_CAD["Chassis Airflow Tails"]
    end

    MB_CAD --> Projector["3D-to-2D Perspective Matrix (project3D)"]
    CPU_CAD --> Projector
    GPU_CAD --> Projector
    Fan_CAD --> Projector
    Chassi_CAD --> Projector

    Projector --> Viewport["HTML5 Canvas (250px compact / 540px modal)"]
```

---

## 4. Liquid Cooling (AIO) Thermal State Machine

```mermaid
stateDiagram-v2
    [*] --> Idle: Cold Startup (<35°C)
    Idle --> Nominal: Normal Load (35°C - 55°C)
    Nominal --> Warm: Sustained Gaming / Compute (55°C - 75°C)
    Warm --> Saturated: Coolant Saturated (>45°C Water)
    Warm --> Critical: Silicon Spike (>85°C)
    Saturated --> Critical: Thermal Exhaust Limit
    Critical --> Nominal: Fan Pre-Ramp & Coolant Cooldown
    
    state Idle {
        [*] --> SilentPump
        SilentPump: Pump @ 70% (Quiet)
    }
    state Nominal {
        [*] --> BalancedPump
        BalancedPump: Pump @ 85% (Balanced)
    }
    state Critical {
        [*] --> EmergencyOverride
        EmergencyOverride: All Fans & Pump @ 100%
    }
```
