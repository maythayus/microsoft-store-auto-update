# Update-StoreApps.ps1
# Verifie et met a jour les applications du Microsoft Store.
#
#  1. Inventaire : liste les applications Store installees et leur version actuelle
#  2. Scan du Store (CIM/MDM) : le Store cherche et installe ses mises a jour
#  3. winget (source msstore) : compare version installee / version disponible
#     et met a jour chaque application qui a une mise a jour
#  4. Bilan : versions avant / apres
#
# Options :
#  -CheckOnly : affiche seulement les versions et les mises a jour disponibles, n'installe rien
#  -Force     : force les mises a jour (redemarre le service d'installation du Store,
#               winget --force, inclut les paquets epingles)
#  -Silent    : mode demarrage (pas de pause, pas d'ouverture du Store, journal dans un fichier)

param([switch]$Silent, [switch]$Force, [switch]$CheckOnly)

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
    if ($Force)     { $relaunchArgs += " -Force" }
    if ($CheckOnly) { $relaunchArgs += " -CheckOnly" }
    if ($Silent)    { $relaunchArgs += " -Silent"; Stop-Transcript | Out-Null }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $relaunchArgs
    exit
}

function Get-StoreAppVersions {
    # Applications installees depuis le Store (hors frameworks et applications systeme)
    Get-AppxPackage -PackageTypeFilter Main -ErrorAction SilentlyContinue |
        Where-Object { $_.SignatureKind -eq "Store" } |
        Sort-Object Name |
        Select-Object Name, @{ n = "Version"; e = { $_.Version } }, PackageFamilyName
}

$mode = if ($CheckOnly) { "verification seule" } elseif ($Force) { "FORCE" } else { "normal" }
Write-Host "=== Mise a jour des applications Microsoft Store (mode $mode) ===" -ForegroundColor Cyan

# --- 1. Inventaire de la bibliotheque ---
Write-Host "`n[1/4] Applications Store installees :" -ForegroundColor Cyan
$before = @(Get-StoreAppVersions)
$before | Format-Table Name, Version -AutoSize | Out-String -Width 200 | Write-Host
Write-Host "$($before.Count) application(s) Store installee(s)."

# --- 2. Scan du Store ---
if ($CheckOnly) {
    Write-Host "`n[2/4] Scan du Store ignore (verification seule)." -ForegroundColor DarkGray
} else {
    if ($Force) {
        # Debloque les telechargements restes "en attente" ou bloques
        Write-Host "`n[Force] Redemarrage du service d'installation du Store (InstallService)..." -ForegroundColor Magenta
        try {
            Restart-Service -Name InstallService -Force -ErrorAction Stop
            Write-Host "Service redemarre." -ForegroundColor Green
        } catch {
            Write-Host "Impossible de redemarrer InstallService : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    try {
        Write-Host "`n[2/4] Declenchement du scan de mises a jour du Store..." -ForegroundColor Cyan
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
}

# --- 3. Comparaison des versions et mise a jour app par app (winget) ---
Write-Host "`n[3/4] Recherche des mises a jour (winget, source msstore)..." -ForegroundColor Cyan

# Module PowerShell officiel de winget : donne des objets (versions installee / disponible)
if (-not (Get-Module -ListAvailable -Name Microsoft.WinGet.Client)) {
    Write-Host "Installation du module Microsoft.WinGet.Client..." -ForegroundColor Yellow
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
    } catch {
        Write-Host "Module non installe : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (Get-Module -ListAvailable -Name Microsoft.WinGet.Client) {
    Import-Module Microsoft.WinGet.Client
    $packages = @(Get-WinGetPackage -Source msstore -ErrorAction SilentlyContinue)
    $updates  = @($packages | Where-Object { $_.IsUpdateAvailable })

    Write-Host "$($packages.Count) application(s) suivie(s) par winget, $($updates.Count) mise(s) a jour disponible(s)."

    if ($updates.Count -gt 0) {
        $updates | Select-Object Name, Id,
            @{ n = "Version installee";   e = { $_.InstalledVersion } },
            @{ n = "Version disponible"; e = { $_.AvailableVersions | Select-Object -First 1 } } |
            Format-Table -AutoSize | Out-String -Width 200 | Write-Host

        if (-not $CheckOnly) {
            foreach ($p in $updates) {
                Write-Host "Mise a jour de $($p.Name) ($($p.Id))..." -ForegroundColor Cyan
                $updateParams = @{ Id = $p.Id; Source = "msstore"; MatchOption = "Equals"; Mode = "Silent" }
                if ($Force) { $updateParams.Force = $true }
                try {
                    $r = Update-WinGetPackage @updateParams -ErrorAction Stop
                    if ($r.Status -eq "Ok") {
                        Write-Host "  OK" -ForegroundColor Green
                    } else {
                        Write-Host "  Echec : $($r.Status) (code $($r.ExtendedErrorCode))" -ForegroundColor Yellow
                    }
                    if ($r.RebootRequired) { Write-Host "  Redemarrage requis." -ForegroundColor Yellow }
                } catch {
                    Write-Host "  Erreur : $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "Toutes les applications suivies par winget sont a jour." -ForegroundColor Green
    }
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    # Repli : winget en ligne de commande
    winget upgrade --source msstore --include-unknown --accept-source-agreements
    if (-not $CheckOnly) {
        $wingetArgs = @("upgrade", "--all", "--source", "msstore", "--silent",
            "--accept-source-agreements", "--accept-package-agreements", "--include-unknown")
        if ($Force) { $wingetArgs += @("--force", "--include-pinned") }
        & winget @wingetArgs
    }
} else {
    Write-Host "winget introuvable : installez 'App Installer' depuis le Store." -ForegroundColor Yellow
}

# --- 4. Bilan des versions ---
if (-not $CheckOnly) {
    Write-Host "`n[4/4] Bilan des versions..." -ForegroundColor Cyan
    $after   = @(Get-StoreAppVersions)
    $old     = @{}
    foreach ($a in $before) { $old[$a.PackageFamilyName] = $a.Version }
    $changed = @($after | Where-Object { $old.ContainsKey($_.PackageFamilyName) -and $old[$_.PackageFamilyName] -ne $_.Version } |
        Select-Object Name, @{ n = "Avant"; e = { $old[$_.PackageFamilyName] } }, @{ n = "Apres"; e = { $_.Version } })

    if ($changed.Count -gt 0) {
        $changed | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
        Write-Host "$($changed.Count) application(s) mise(s) a jour." -ForegroundColor Green
    } else {
        Write-Host "Aucune version modifiee pour l'instant (le Store peut encore installer en arriere-plan)."
    }
}

Write-Host "`nTermine." -ForegroundColor Green

if ($Silent) {
    Stop-Transcript | Out-Null
} else {
    if (-not $CheckOnly) { Start-Process "ms-windows-store://downloadsandupdates" }
    Read-Host "Appuyez sur Entree pour fermer"
}
