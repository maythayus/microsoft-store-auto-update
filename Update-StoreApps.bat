@echo off
REM Lance Update-StoreApps.ps1 (place dans le meme dossier) sans bloquer sur l'ExecutionPolicy
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-StoreApps.ps1"
