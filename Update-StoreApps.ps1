# Update-StoreApps.ps1
# Lance la mise a jour des applications du Microsoft Store.
# Methode 1 : declenchement du scan de mises a jour du Store (CIM/MDM, admin requis)
# Methode 2 : winget sur la source msstore (installe les mises a jour disponibles)
# -Silent : mode demarrage (pas de pause, pas d'ouverture du Store, journal dans un fichier)

param([switch]$Silent)

if ($Silent) {
    $logDir = Join-Path $env:ProgramData "UpdateStoreApps"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    Start-Transcript -Path (Join-Path $logDir "derniere-execution.log") -Force | Out-Null
}

# --- Relance automatique en administrateur si necessaire ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Relance en administrateur..." -ForegroundColor Yellow
    $relaunchArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Silent) { $relaunchArgs += " -Silent"; Stop-Transcript | Out-Null }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $relaunchArgs
    exit
}

Write-Host "=== Mise a jour des applications Microsoft Store ===" -ForegroundColor Cyan

# --- Methode 1 : forcer le Store a chercher et installer ses mises a jour ---
try {
    Write-Host "`n[1/2] Declenchement du scan de mises a jour du Store..." -ForegroundColor Cyan
    $result = Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" `
        -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" -ErrorAction Stop |
        Invoke-CimMethod -MethodName UpdateScanMethod -ErrorAction Stop
    if ($result.ReturnValue -eq 0) {
        Write-Host "Scan lance : le Store telecharge les mises a jour en arriere-plan." -ForegroundColor Green
    } else {
        Write-Host "Scan termine avec le code $($result.ReturnValue)." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Methode CIM indisponible : $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Methode 2 : winget, source msstore ---
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "`n[2/2] Mises a jour via winget (source msstore)..." -ForegroundColor Cyan
    winget upgrade --source msstore
    winget upgrade --all --source msstore --silent `
        --accept-source-agreements --accept-package-agreements --include-unknown
} else {
    Write-Host "winget introuvable : installez 'App Installer' depuis le Store." -ForegroundColor Yellow
}

# --- Optionnel : ouvrir la page Telechargements du Store pour suivre l'avancement ---
Write-Host "`nTermine." -ForegroundColor Green

if ($Silent) {
    Stop-Transcript | Out-Null
} else {
    Start-Process "ms-windows-store://downloadsandupdates"
    Read-Host "Appuyez sur Entree pour fermer"
}
