using System;
using System.Runtime.InteropServices;
using System.Text;

namespace AetherControl.Daemon.Hardware;

/// <summary>
/// Ring-3 direct P/Invoke into NVIDIA Management Library (nvml.dll).
/// Bypasses WMI completely, safe under Windows 11 HVCI / Memory Integrity,
/// and provides sub-millisecond access to GPU temperature, milliwatt board power, and clocks.
/// </summary>
public static class NativeNvml
{
    private const string NvmlLibrary = "nvml.dll";

    public enum NvmlReturn : int
    {
        Success = 0,
        Uninitialized = 1,
        InvalidArgument = 2,
        NotSupported = 3,
        NoPermission = 4,
        NotFound = 6
    }

    public enum NvmlTemperatureSensors : int
    {
        Gpu = 0
    }

    public enum NvmlClockType : int
    {
        Graphics = 0,
        Sm = 1,
        Mem = 2,
        Video = 3
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct NvmlUtilization
    {
        public uint Gpu;
        public uint Memory;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct NvmlMemory
    {
        public ulong Total;
        public ulong Free;
        public ulong Used;
    }

    [DllImport(NvmlLibrary, EntryPoint = "nvmlInit_v2", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn Init();

    [DllImport(NvmlLibrary, EntryPoint = "nvmlShutdown", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn Shutdown();

    [DllImport(NvmlLibrary, EntryPoint = "nvmlDeviceGetCount_v2", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn DeviceGetCount(out uint deviceCount);

    [DllImport(NvmlLibrary, EntryPoint = "nvmlDeviceGetHandleByIndex_v2", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn DeviceGetHandleByIndex(uint index, out IntPtr device);

    [DllImport(NvmlLibrary, EntryPoint = "nvmlDeviceGetName", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    public static extern NvmlReturn DeviceGetName(IntPtr device, StringBuilder name, uint length);

    [DllImport(NvmlLibrary, EntryPoint = "nvmlDeviceGetTemperature", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn DeviceGetTemperature(IntPtr device, NvmlTemperatureSensors sensorType, out uint temp);

    [DllImport(NvmlLibrary, EntryPoint = "nvmlDeviceGetPowerUsage", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn DeviceGetPowerUsage(IntPtr device, out uint powerMilliwatts);

    [DllImport(NvmlLibrary, EntryPoint = "nvmlDeviceGetEnforcedPowerLimit", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn DeviceGetEnforcedPowerLimit(IntPtr device, out uint limitMilliwatts);

    [DllImport(NvmlLibrary, EntryPoint = "nvmlDeviceGetFanSpeed", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn DeviceGetFanSpeed(IntPtr device, out uint speedPercent);

    [DllImport(NvmlLibrary, EntryPoint = "nvmlDeviceGetClockInfo", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn DeviceGetClockInfo(IntPtr device, NvmlClockType type, out uint clockMhz);

    [DllImport(NvmlLibrary, EntryPoint = "nvmlDeviceGetUtilizationRates", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn DeviceGetUtilizationRates(IntPtr device, out NvmlUtilization utilization);

    [DllImport(NvmlLibrary, EntryPoint = "nvmlDeviceGetMemoryInfo", CallingConvention = CallingConvention.Cdecl)]
    public static extern NvmlReturn DeviceGetMemoryInfo(IntPtr device, out NvmlMemory memory);
}
