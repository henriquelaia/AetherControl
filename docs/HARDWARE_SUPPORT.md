# AetherControl — Supported Hardware & Auto-Scanner Guide

When **AetherControl** starts on any Windows 10/11 PC, `Invoke-HardwareTopologyScan` queries PCIe, SMBIOS/CIM, NVML, and USB/PnP buses to identify installed components and configure sensor channels automatically.

---

## 1. Processors (CPUs)

| Vendor | Supported Families | Auto-Detected Attributes |
| :--- | :--- | :--- |
| **AMD** | • Ryzen 3000 / 5000 / 7000 / 9000 Series (`Zen 2` – `Zen 5`)<br>• Ryzen X3D Series<br>• Ryzen Threadripper | Full Model Name, Concise Display Name, Physical Cores, Logical Threads, Max Boost Clock (`MHz`), Estimated Package TDP (`65W` / `105W` / `125W+`), Kernel Per-Thread Load (`GetSystemTimes`). |
| **Intel** | • Core 10th – 14th Gen (`i3` / `i5` / `i7` / `i9`)<br>• Core Ultra Series 1 & 2<br>• Xeon Workstation | Full Model Name, Concise Display Name, Core / Thread Count, Max Turbo Clock (`MHz`), Estimated Package TDP, Kernel Load. |

---

## 2. Graphics Cards (GPUs)

| Vendor | Telemetry Backend | Auto-Detected Metrics |
| :--- | :--- | :--- |
| **NVIDIA** | **Tier 1 Native Ring-3 (`nvml.dll` P/Invoke)**<br>Supported on GeForce GTX 10-series, RTX 20-series, RTX 30-series, RTX 40-series, and RTX 50-series GPUs. | GPU Die Temperature (`°C`), Hotspot Estimate (`°C`), Board Power Draw (`W`), Enforced Power Limit (`W`), Graphics & Memory Clocks (`MHz`), Core Utilization (`%`), Dedicated VRAM Used / Total (`MB`), Fan Speed (`%`), Zero-RPM Chatter Guard. |
| **AMD Radeon** | **Tier 2 WDDM / CIM Telemetry Bridge**<br>Supported on Radeon RX 6000 / 7000 / 9000 Series & Integrated Radeon Graphics. | Adapter Model Name, Total VRAM (`MB`), Dynamic Core Load & Thermal Envelope. |
| **Intel Arc** | **Tier 2 WDDM / CIM Telemetry Bridge**<br>Supported on Intel Arc A-Series / B-Series & Iris Xe. | Adapter Model Name, Total VRAM (`MB`), Dynamic Load & Thermal Envelope. |

---

## 3. Motherboards & Super I/O Controllers

AetherControl inspects `Win32_BaseBoard` and `Win32_BIOS` and maps your motherboard vendor to its Super I/O PWM controller family:

| Motherboard Brand | Series Covered | Auto-Mapped Super I/O Family |
| :--- | :--- | :--- |
| **Gigabyte** | B450, B550, B650, X570, X670, Z690, Z790 (*AORUS / Gaming / UD / DS3H*) | `ITE IT8686E / IT8688E` |
| **ASUS** | ROG Crosshair, ROG Strix, TUF Gaming, ProArt, Prime | `Nuvoton NCT6798D / ROG IO` |
| **MSI** | MEG, MPG, MAG (*Tomahawk / Mortar / Carbon*), PRO Series | `Nuvoton NCT6797D / MSI IO` |
| **ASRock** | Taichi, Steel Legend, Phantom Gaming, Pro RS | `Nuvoton NCT6791D` |

---

## 4. Water Cooling (AIO) & Air Coolers

During startup (or when clicking the PC hardware chip in the top header and selecting **`Atualizar / Refresh`**), AetherControl scans `Win32_PnPEntity` for USB/HID liquid cooling controllers:
- **NZXT Kraken** (`X-Series`, `Z-Series`, `Kraken Elite`)
- **Corsair iCUE** (`Commander CORE`, `Capellix`, `iCUE LINK`)
- **Arctic** (`Liquid Freezer II / III` via Motherboard Hybrid `W_PUMP` PWM)
- **Lian Li** (`Galahad II Trinity / LCD`)
- **ASUS ROG** (`Ryujin II / III`)

If no standalone USB AIO controller is found, AetherControl binds to the motherboard's **Hybrid `W_PUMP` / `CPU_FAN` PWM header** so standard 3-pin/4-pin AIO pumps and air coolers work out of the box.
