@echo off
REM Affiche les versions des apps du Store et les mises a jour disponibles, sans rien installer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-StoreApps.ps1" -CheckOnly
