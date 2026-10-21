---
name: Hardware Support Request
about: Request telemetry or fan control support for new motherboard, GPU, or AIO cooler
title: '[HW] Support for <Component Name>'
labels: ['hardware-support', 'enhancement']
assignees: ''
---

## Hardware Component Information
- **Component Type:** [ ] Motherboard Super I/O / [ ] GPU / [ ] AIO Cooler / [ ] Fan Hub
- **Manufacturer:** (e.g. MSI, ASRock, Lian Li, DeepCool)
- **Exact Model Name:** 

## Device Identification Details
Please run PowerShell as Administrator and paste the output of the relevant command:

### For Motherboard & Super I/O:
```powershell
Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer, Product, Version
Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion, Manufacturer
```

### For Liquid Cooler / USB Hubs:
```powershell
Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -match "USB" } | Select-Object Name, DeviceID
```

## Additional Context
Add any other details, user manuals, or open-source driver links for this hardware.
