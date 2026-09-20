@echo off
:: ============================================================================
::  DLSS 5 Neural Rendering su AMD Radeon - Football Life 2026 / PES 2021
::  Disinstallazione  /  Uninstall
:: ============================================================================
::  Rimuove SOLO i file aggiunti dall'installatore.
::  Removes ONLY the files added by the installer.
:: ============================================================================

title Disinstallazione DLSS 5 Neural Rendering - AMD Radeon

net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  Richiedo i privilegi di amministratore...
    echo  Requesting administrator rights...
    echo.
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0_installer-gui.ps1" -Disinstalla

if errorlevel 1 (
    echo.
    echo  La finestra non si e' aperta: uso la versione testuale.
    echo  The window did not open: falling back to the text version.
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_installa.ps1" -Disinstalla
    pause
)
