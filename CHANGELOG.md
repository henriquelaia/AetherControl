# Changelog

All notable changes to the **AetherControl** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [3.1.0] - 2026-10-21

### Added
- **Solid CAD 3D Digital Twin Engine:**
  - High-contrast solid geometry rendering for Motherboard PCB (`rgba(28, 32, 44)`), metallic VRM heatsinks, and illuminated DDR5 memory sticks.
  - Solid GPU shroud with brushed metallic backplate and dual-axial rotors spinning at live sensor RPM.
  - CPU AIO water block with reactive liquid plasma thermal core (Cool Blue `<40°C` $\rightarrow$ Emerald $\rightarrow$ Amber $\rightarrow$ Critical Rose `>85°C`).
  - Braided coolant tubing with circulating fluid particles synchronized to pump speed.
  - Aerodynamic wind-tunnel airflow tails representing chassis intake and exhaust vectors.
- **Expanded 3D Inspection Modal:**
  - Full-screen CAD inspection viewport (`540px` height) with interactive HUD callout pins.
  - Orbit rotation with mouse-drag, smooth mouse-wheel zooming (`0.9x`–`3.8x`), and single-click camera reset.
  - Multi-mode toggles: *Heatmap*, *Airflow*, *Solid CAD*, and *Wireframe*.
- **Desktop & Start Menu Shortcut Helpers:**
  - One-click batch launcher `Criar-Atalho-Ambiente-Trabalho.bat` (PT) and `Create-Desktop-Shortcut.bat` (EN).
  - Multi-resolution Windows application icon (`assets/aethercontrol.ico`) and browser favicon.
  - Support for local Desktop, OneDrive synchronized Desktop, and Windows Start Menu.
- **Documentation & User Guide:**
  - Illustrated end-user guide `GUIA_RAPIDO.md` covering installation, fan tuning, AIO maintenance, and troubleshooting.

### Fixed
- Fixed global canvas CSS style (`canvas { height: 42px; }`) that constrained the 3D twin canvas element.
- Corrected perspective projection mathematics in `project3D()` to allow linear, responsive zoom scaling.

---

## [3.0.0] - 2026-10-21

### Added
- **Community Profiles Hub:**
  - One-click profile applicator for *HydroLoop 360mm Equilibrium*, *Whisper SFF Silent*, *Esports 240Hz Response*, and *Workstation 24/7 Render*.
  - Live synchronization between community fan curves and AIO liquid cooling targets.
- **Modular Plugin Engine:**
  - Extensible plugin architecture with runtime toggle states (`csv-flight-recorder`, `rgb-thermal-sync`, `eco-idle-drop`, `osd-stream-bridge`).
- **AIO Liquid Cooling Card:**
  - Real-time Coolant Temperature (`°C`), Pump Speed (`RPM`), Ambient Delta, and Thermal Saturation (`%`).
  - Pump profile presets (*Quiet*, *Balanced*, *Performance*) and 15-second acoustic bubble purge cycle.
- **Per-Channel Fan Identification:**
  - 1-click test button spinning targeted fan channels (`W_PUMP`, `CPU_FAN1`, `SYS_FAN1`, `GPU_FAN1`) to 100% for 3.5 seconds.
- **Universal Hardware Auto-Scanner:**
  - Automatic topology discovery across AMD/Intel CPUs, NVIDIA/AMD GPUs, and Gigabyte/ASUS/MSI/ASRock Super I/O chips.

---

## [2.0.0] - 2026-10-20

### Added
- Bento-box interface layout inspired by Vercel and Linear design systems.
- Seamless Dark Mode (`#09090B`) and Light Mode (`#FFFFFF`) with 1-click toggle and persistence.
- Ring-3 native C# P/Invoke bridge (`nvml.dll`, `kernel32.dll`, `user32.dll`) compiled in-memory via .NET at startup.
- Full bilingual localization: Portuguese (PT-PT) and English (EN).
- Command Palette (`Ctrl + K`) for rapid keyboard navigation.

---

## [1.0.0] - 2026-10-19

### Added
- Initial hardware telemetry prototype and 5-point cubic-spline fan curve controller.
- Local REST API daemon running on `127.0.0.1:5175`.
