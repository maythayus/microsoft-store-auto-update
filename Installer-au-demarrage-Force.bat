@echo off
REM Installe la mise a jour automatique des apps du Store au demarrage, en mode force
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-StartupTask.ps1" -Force
