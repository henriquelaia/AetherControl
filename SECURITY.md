# Security Policy

## Supported Versions

We provide active security updates for the current major branch of **AetherControl**:

| Version | Supported          |
| ------- | ------------------ |
| 3.x.x   | :white_check_mark: |
| < 3.0   | :x:                |

---

## Security Philosophy & Architecture Safety

AetherControl is architected from the ground up with defensive security principles:

1. **Strict Localhost Binding:** The internal telemetry daemon binds exclusively to `127.0.0.1:5175`. It refuses all external network interfaces (`0.0.0.0`, LAN, or WAN).
2. **Ring-3 User Mode Privileges:** Unlike legacy tools that deploy arbitrary Ring-0 kernel drivers with read/write memory access vulnerabilities, AetherControl utilizes standard Windows user-mode APIs (`nvml.dll`, `kernel32.dll`, `user32.dll`, and SMBIOS/WMI).
3. **No External Network Calls / Zero Telemetry:** AetherControl transmits **zero** user data, analytics, or hardware fingerprints across the Internet. All profile files and settings reside locally in `%LOCALAPPDATA%\AetherControl`.
4. **Thermal Safety Guardrails:** Even under aggressive manual user fan curves, AetherControl implements a hardware failsafe override: if CPU die temperature exceeds `85°C` or GPU exceeds `88°C`, PWM fan output automatically defaults to `100%` safety cooling.

---

## Reporting a Vulnerability

If you discover a security vulnerability or hardware safety issue in AetherControl, please report it responsibly:

1. **Do not disclose the issue publicly** in GitHub Issues or Discussions.
2. Email the maintainer directly at: `henrique.laia@proton.me` (or submit a Private Vulnerability Advisory via GitHub Security Advisories).
3. Include:
   * A detailed description of the potential vulnerability.
   * Steps to reproduce or proof-of-concept script.
   * Affected operating system version and hardware components.

You will receive an acknowledgment within 24 hours, and patches will be prioritized for immediate release.
