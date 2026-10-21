@echo off
title AetherControl // Next-Gen Hardware Monitor & Predictive Fan Controller
color 0B

:: Check for Administrator privileges; if not elevated, request UAC
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [*] A solicitar privilegios de Administrador para controlo fisico das ventoinhas...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo ============================================================================
echo   AETHERCONTROL v3.1 // UNIVERSAL HARDWARE TELEMETRY ^& THERMAL STUDIO
echo   MODO ADMINISTRADOR ATIVO // CONTROLO FISICO DE HARDWARE DESBLOQUEADO
echo ============================================================================
echo.

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0AetherControl-NativeDaemon.ps1"
pause
