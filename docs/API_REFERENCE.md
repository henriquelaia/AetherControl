# AetherControl — Local REST API Reference

The AetherControl daemon exposes a high-performance, low-latency REST API on `http://127.0.0.1:5175`. All responses are formatted in strict JSON with sub-2ms typical response latency.

---

## 1. Endpoints Overview

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/telemetry` | Returns real-time sensor snapshot (CPU, GPU, RAM, Coolant, Fans, Bottlenecks). |
| `POST` | `/api/v1/fan-curve` | Updates the active 5-point fan curve nodes, hysteresis, and control mode. |
| `POST` | `/api/v1/fans/identify` | Triggers a 3.5s 100% spin-up test for a targeted physical fan channel. |
| `GET` | `/api/v1/profiles` | Returns the curated catalog of community cooling profiles. |
| `POST` | `/api/v1/profiles/apply` | Applies a specific community profile by ID. |
| `GET` | `/api/v1/plugins` | Returns registered modular plugins and their active states. |
| `POST` | `/api/v1/plugins/toggle` | Enables or disables a modular plugin. |
| `POST` | `/api/v1/hardware/refresh` | Re-triggers a full PCIe, SMBIOS, and NVML hardware topology scan. |
| `POST` | `/api/v1/shutdown` | Safely terminates daemon and releases hardware control to BIOS. |

---

## 2. Telemetry Snapshot

### Request
```http
GET /api/v1/telemetry HTTP/1.1
Host: 127.0.0.1:5175
Accept: application/json
```

### Response
```json
{
  "timestamp": 1729510000000,
  "cpu": {
    "name": "AMD Ryzen 7 3800X 8-Core Processor",
    "shortName": "Ryzen 7 3800X",
    "tempC": 68.4,
    "loadPct": 32.5,
    "clockMhz": 4250,
    "powerW": 74.2
  },
  "gpu": {
    "name": "NVIDIA GeForce RTX 3060 Ti",
    "shortName": "RTX 3060 Ti",
    "tempC": 59.0,
    "hotspotC": 67.2,
    "loadPct": 48.0,
    "vramUsedMb": 3840,
    "vramTotalMb": 8192,
    "powerW": 165.0,
    "fanSpeedPct": 52
  },
  "cooling": {
    "coolantTempC": 31.8,
    "ambientDeltaC": 9.8,
    "pumpRpm": 2450,
    "pumpPwmPct": 85,
    "thermalSaturationPct": 42.0,
    "purging": false
  },
  "fans": [
    { "id": "W_PUMP", "name": "AIO Liquid Pump", "rpm": 2450, "pwm": 85, "identifying": false },
    { "id": "CPU_FAN1", "name": "Radiator Fans (Push-Pull)", "rpm": 1280, "pwm": 54, "identifying": false },
    { "id": "SYS_FAN1", "name": "Front Intake Array", "rpm": 1050, "pwm": 48, "identifying": false },
    { "id": "GPU_FAN1", "name": "GPU Shroud Rotors", "rpm": 1420, "pwm": 52, "identifying": false }
  ],
  "bottleneck": {
    "active": "GPU Core Limited",
    "color": "#10B981"
  }
}
```

---

## 3. Fan Curve Update

### Request
```http
POST /api/v1/fan-curve HTTP/1.1
Host: 127.0.0.1:5175
Content-Type: application/json

{
  "preset": "Custom",
  "sensorSource": "Hottest",
  "hysteresisC": 3.0,
  "zeroRpmGuard": true,
  "nodes": [
    { "temp": 30, "pwm": 25 },
    { "temp": 45, "pwm": 40 },
    { "temp": 60, "pwm": 60 },
    { "temp": 75, "pwm": 82 },
    { "temp": 85, "pwm": 100 }
  ]
}
```

### Response
```json
{
  "status": "ok",
  "message": "Fan curve applied successfully",
  "activeNodes": 5
}
```

---

## 4. Fan Identification Test

Acelerates a targeted fan channel to 100% for 3.5 seconds to physically locate it inside the chassis.

### Request
```http
POST /api/v1/fans/identify HTTP/1.1
Host: 127.0.0.1:5175
Content-Type: application/json

{
  "channelId": "CPU_FAN1",
  "durationMs": 3500
}
```

### Response
```json
{
  "status": "ok",
  "channelId": "CPU_FAN1",
  "overridePwm": 100,
  "durationMs": 3500
}
```

---

## 5. Community Profiles & Plugins

### Apply Profile
```http
POST /api/v1/profiles/apply HTTP/1.1
Host: 127.0.0.1:5175
Content-Type: application/json

{
  "profileId": "hydroloop-360-equil"
}
```

### Toggle Plugin
```http
POST /api/v1/plugins/toggle HTTP/1.1
Host: 127.0.0.1:5175
Content-Type: application/json

{
  "pluginId": "csv-flight-recorder",
  "enabled": true
}
```
