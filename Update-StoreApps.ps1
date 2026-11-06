# Update-StoreApps.ps1
# Verifie et met a jour les applications du Microsoft Store.
#
#  1. Inventaire : liste les applications Store installees et leur version actuelle
#  2. Store CLI (store.exe) : "store updates --apply true" verifie et installe
#     les mises a jour de TOUTES les applications Store (methode principale)
#  3. Scan du Store (CIM/MDM) : complement / secours si store.exe est absent
#  4. winget (source msstore) : met a jour les applications reconnues par winget
#  5. Bilan : attend la fin des installations et compare les versions avant / apres
#
# Options :
#  -CheckOnly   : affiche les versions et les mises a jour disponibles, n'installe rien
#  -Force       : redemarre le service d'installation du Store (InstallService),
#                 winget --force, inclut les paquets epingles
#  -Repair      : repare le Store avant les mises a jour (wsreset + reenregistrement du Store)
#  -WaitMinutes : duree max d'attente de la fin des installations (defaut 5, 0 = pas d'attente)
#  -Silent      : mode demarrage (pas de pause, pas d'ouverture du Store, journal dans un fichier)

param(
    [switch]$Silent,
    [switch]$Force,
    [switch]$CheckOnly,
    [switch]$Repair,
    [int]$WaitMinutes = 5
)

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
    $relaunchArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -WaitMinutes $WaitMinutes"
    if ($Force)     { $relaunchArgs += " -Force" }
    if ($CheckOnly) { $relaunchArgs += " -CheckOnly" }
    if ($Repair)    { $relaunchArgs += " -Repair" }
    if ($Silent)    { $relaunchArgs += " -Silent"; Stop-Transcript | Out-Null }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $relaunchArgs
    exit
}

# Affichage correct des tableaux de store.exe
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

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
Write-Host "`n[1/5] Applications Store installees :" -ForegroundColor Cyan
$before = @(Get-StoreAppVersions)
$before | Format-Table Name, Version -AutoSize | Out-String -Width 200 | Write-Host
Write-Host "$($before.Count) application(s) Store installee(s)."

# --- Preparation : reparation et mode force ---
if ($Repair -and -not $CheckOnly) {
    Write-Host "`n[Reparation] Reinitialisation du cache du Store (wsreset)..." -ForegroundColor Magenta
    try {
        Start-Process -FilePath "wsreset.exe" -Wait -ErrorAction Stop
        # wsreset rouvre le Store : on le referme pour continuer
        Get-Process -Name WinStore.App -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "Cache reinitialise." -ForegroundColor Green
    } catch {
        Write-Host "wsreset impossible : $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host "[Reparation] Reenregistrement de l'application Microsoft Store..." -ForegroundColor Magenta
    try {
        Get-AppxPackage Microsoft.WindowsStore | ForEach-Object {
            Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction Stop
        }
        Write-Host "Store reenregistre." -ForegroundColor Green
    } catch {
        Write-Host "Reenregistrement impossible : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($Force -and -not $CheckOnly) {
    # Debloque les telechargements restes "en attente" ou bloques
    Write-Host "`n[Force] Redemarrage du service d'installation du Store (InstallService)..." -ForegroundColor Magenta
    try {
        Restart-Service -Name InstallService -Force -ErrorAction Stop
        Write-Host "Service redemarre." -ForegroundColor Green
    } catch {
        Write-Host "Impossible de redemarrer InstallService : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- 2. Store CLI : verification + installation de toutes les mises a jour ---
$storeStarted = 0
$storeCli = Get-Command store.exe -ErrorAction SilentlyContinue
if ($storeCli) {
    Write-Host "`n[2/5] Verification des mises a jour avec store.exe..." -ForegroundColor Cyan
    $applyValue = if ($CheckOnly) { "false" } else { "true" }
    $out = & $storeCli.Source updates --apply $applyValue 2>&1 | ForEach-Object { "$_" }
    # Retire l'invite interactive que store.exe affiche en mode verification seule
    $out | Where-Object { $_ -notmatch "Would you like to install|Failed to read input" } | Write-Host
    $m = [regex]::Match(($out -join "`n"), "Started installation of (\d+)")
    if ($m.Success) { $storeStarted = [int]$m.Groups[1].Value }
} else {
    Write-Host "`n[2/5] store.exe introuvable (Windows/Store trop ancien) : methodes de secours." -ForegroundColor Yellow
}

# --- 3. Scan du Store (CIM/MDM) ---
if ($CheckOnly) {
    Write-Host "`n[3/5] Scan du Store ignore (verification seule)." -ForegroundColor DarkGray
} else {
    try {
        Write-Host "`n[3/5] Declenchement du scan de mises a jour du Store (CIM)..." -ForegroundColor Cyan
        $result = Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" `
            -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" -ErrorAction Stop |
            Invoke-CimMethod -MethodName UpdateScanMethod -ErrorAction Stop
        if ($result.ReturnValue -eq 0) {
            Write-Host "Scan lance." -ForegroundColor Green
        } else {
            Write-Host "Scan termine avec le code $($result.ReturnValue)." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Methode CIM indisponible : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- 4. winget : applications reconnues par la source msstore ---
Write-Host "`n[4/5] Recherche des mises a jour (winget, source msstore)..." -ForegroundColor Cyan

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

# --- 5. Bilan des versions ---
if (-not $CheckOnly) {
    Write-Host "`n[5/5] Bilan des versions..." -ForegroundColor Cyan
    $old = @{}
    foreach ($a in $before) { $old[$a.PackageFamilyName] = $a.Version }

    function Get-ChangedApps {
        @(Get-StoreAppVersions | Where-Object {
                $old.ContainsKey($_.PackageFamilyName) -and $old[$_.PackageFamilyName] -ne $_.Version } |
            Select-Object Name, @{ n = "Avant"; e = { $old[$_.PackageFamilyName] } }, @{ n = "Apres"; e = { $_.Version } })
    }

    # Le Store installe en arriere-plan : on attend que les mises a jour lancees se terminent
    $changed  = Get-ChangedApps
    $deadline = (Get-Date).AddMinutes($WaitMinutes)
    if ($storeStarted -gt 0 -and $WaitMinutes -gt 0) {
        Write-Host "Attente de la fin des installations ($storeStarted lancee(s), $WaitMinutes min max)..."
        while ($changed.Count -lt $storeStarted -and (Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 15
            $changed = Get-ChangedApps
            Write-Host "  $($changed.Count) / $storeStarted terminee(s)..."
        }
    }

    if ($changed.Count -gt 0) {
        $changed | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
        Write-Host "$($changed.Count) application(s) mise(s) a jour." -ForegroundColor Green
    }
    if ($changed.Count -lt $storeStarted) {
        Write-Host "Des installations sont encore en cours dans le Store (les applications ouvertes sont mises a jour a leur fermeture)." -ForegroundColor Yellow
    } elseif ($changed.Count -eq 0) {
        Write-Host "Aucune version modifiee."
    }
}

Write-Host "`nTermine." -ForegroundColor Green

if ($Silent) {
    Stop-Transcript | Out-Null
} else {
    if (-not $CheckOnly) { Start-Process "ms-windows-store://downloadsandupdates" }
    Read-Host "Appuyez sur Entree pour fermer"
}
