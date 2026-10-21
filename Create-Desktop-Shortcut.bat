@echo off
title AetherControl // Desktop Shortcut Creator
color 0A
cls
echo ============================================================================
echo   AETHERCONTROL // DESKTOP ^& START MENU SHORTCUT CREATOR
echo ============================================================================
echo.
echo Setting up shortcut with the official AetherControl icon...
echo.

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AetherControl.ps1" -InstallShortcutOnly

echo.
echo ============================================================================
echo   Done! "AetherControl Studio" is now ready on your Desktop and Start Menu.
echo ============================================================================
echo.
set /p LAUNCH="Do you want to launch AetherControl now? (Y/n): "
if /i "%LAUNCH%"=="n" goto :end

echo.
echo Launching AetherControl Studio...
start "" "%~dp0Launch-AetherControl.bat"

:end
