@echo off
chcp 65001 >nul
title AetherControl // Criador de Atalho
color 0A
cls
echo ============================================================================
echo   AETHERCONTROL // CRIADOR DE ATALHO NO AMBIENTE DE TRABALHO
echo ============================================================================
echo.
echo A configurar o atalho com o ícone oficial do AetherControl...
echo.

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AetherControl.ps1" -InstallShortcutOnly

echo.
echo ============================================================================
echo   Tudo pronto! O atalho "AetherControl Studio" está no seu Ambiente de Trabalho.
echo ============================================================================
echo.
set /p LAUNCH="Deseja abrir o AetherControl agora? (S/n): "
if /i "%LAUNCH%"=="n" goto :end
if /i "%LAUNCH%"=="nao" goto :end
if /i "%LAUNCH%"=="não" goto :end

echo.
echo A iniciar o AetherControl Studio...
start "" "%~dp0Launch-AetherControl.bat"

:end
