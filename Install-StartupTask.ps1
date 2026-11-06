# Install-StartupTask.ps1
# Installe (ou supprime avec -Uninstall) une tache planifiee qui lance
# Update-StoreApps.ps1 a chaque ouverture de session Windows, en administrateur,
# sans fenetre UAC.

# -Force : la tache lancera les mises a jour en mode force (voir Update-StoreApps.ps1)

param([switch]$Uninstall, [switch]$Force)

$taskName   = "Mise a jour apps Microsoft Store"
$installDir = Join-Path $env:ProgramData "UpdateStoreApps"
$target     = Join-Path $installDir "Update-StoreApps.ps1"

# --- Admin requis pour creer une tache "privileges les plus eleves" ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $relaunchArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Uninstall) { $relaunchArgs += " -Uninstall" }
    if ($Force)     { $relaunchArgs += " -Force" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $relaunchArgs
    exit
}

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Tache '$taskName' supprimee." -ForegroundColor Green
    Read-Host "Appuyez sur Entree pour fermer"
    exit
}

# --- Copie du script dans un emplacement permanent ---
$source = Join-Path $PSScriptRoot "Update-StoreApps.ps1"
if (-not (Test-Path $source)) {
    Write-Host "Update-StoreApps.ps1 introuvable a cote de ce script." -ForegroundColor Red
    Read-Host "Appuyez sur Entree pour fermer"
    exit 1
}
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item -Path $source -Destination $target -Force

# --- Creation de la tache planifiee ---
$user = "$env:USERDOMAIN\$env:USERNAME"

$taskArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$target`" -Silent"
if ($Force) { $taskArgs += " -Force" }

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $taskArgs

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$trigger.Delay = "PT2M"   # attend 2 minutes apres l'ouverture de session (reseau pret)

$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Tache '$taskName' installee." -ForegroundColor Green
if ($Force) { Write-Host "Mode force active." -ForegroundColor Magenta }
Write-Host "Script copie dans : $target"
Write-Host "Journal de la derniere execution : $installDir\derniere-execution.log"
Write-Host "Pour tester tout de suite : Start-ScheduledTask -TaskName '$taskName'"
Read-Host "Appuyez sur Entree pour fermer"
