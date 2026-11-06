@echo off
REM Lance Update-StoreApps.ps1 en mode force (place dans le meme dossier)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-StoreApps.ps1" -Force
