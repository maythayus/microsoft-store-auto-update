@echo off
REM Supprime la tache de mise a jour automatique des apps du Store
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-StartupTask.ps1" -Uninstall
