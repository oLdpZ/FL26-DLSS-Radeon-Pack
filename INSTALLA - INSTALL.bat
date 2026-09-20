@echo off
:: ============================================================================
::  DLSS 5 Neural Rendering su AMD Radeon - Football Life 2026 / PES 2021
::  Installatore  /  Installer
:: ============================================================================
::  Fai doppio clic su questo file.  /  Just double-click this file.
::
::  Apre una finestra: premi INSTALLA e segui quello che dice.
::  Opens a window: press INSTALL and follow along.
:: ============================================================================

title DLSS 5 Neural Rendering - AMD Radeon

:: Servono i privilegi di amministratore per scrivere nella cartella del gioco
:: Administrator rights are needed to write into the game folder
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  Richiedo i privilegi di amministratore...
    echo  Requesting administrator rights...
    echo.
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: -STA serve all'interfaccia grafica e alla musica
:: -STA is required by the graphical interface and the music
powershell -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0_installer-gui.ps1"

:: Se la finestra non si apre (PC molto vecchi), ripiega sulla versione testuale
:: If the window does not open (very old PCs), fall back to the text version
if errorlevel 1 (
    echo.
    echo  La finestra non si e' aperta: uso la versione testuale.
    echo  The window did not open: falling back to the text version.
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_installa.ps1"
    pause
)
