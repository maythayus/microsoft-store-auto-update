@echo off
REM Repare le Microsoft Store (cache + reenregistrement) puis force les mises a jour
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-StoreApps.ps1" -Repair -Force
