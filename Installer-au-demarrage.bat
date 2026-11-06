@echo off
REM Installe la mise a jour automatique des apps du Store a l'ouverture de session
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-StartupTask.ps1"
