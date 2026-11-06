# Notes de version

## v1.1.0 — 2026-11-06

### Nouveautés

- **Vérification des versions** : le script liste les applications Store installées avec leur version, compare la version installée à la version disponible (module `Microsoft.WinGet.Client`, installé automatiquement) et met à jour chaque application concernée.
- **Bilan avant / après** des versions en fin d'exécution.
- **Option `-CheckOnly`** : affiche les versions et les mises à jour disponibles sans rien installer (`Verifier-versions.bat`).
- **Option `-Force`** : redémarre le service d'installation du Store (`InstallService`), puis met à jour avec `winget --force` en incluant les paquets épinglés (`Update-StoreApps-Force.bat`).
- **`Install-StartupTask.ps1 -Force`** : tâche au démarrage en mode forcé (`Installer-au-demarrage-Force.bat`).

### Changements

- Si le module `Microsoft.WinGet.Client` ne peut pas être installé, le script se replie sur `winget upgrade --all`.

## v1.0.0 — 2026-11-06

Première version.

### Nouveautés

- **`Update-StoreApps.ps1`** : mise à jour des applications du Microsoft Store
  - déclenchement du scan de mises à jour du Store (CIM/MDM `UpdateScanMethod`) ;
  - mise à jour de toutes les applications de la source `msstore` via winget ;
  - relance automatique en administrateur ;
  - option `-Silent` pour l'exécution au démarrage (sans fenêtre, sans pause, journal dans `C:\ProgramData\UpdateStoreApps\derniere-execution.log`).
- **`Install-StartupTask.ps1`** : tâche planifiée à l'ouverture de session
  - privilèges les plus élevés, sans invite UAC ;
  - délai de 2 minutes, réseau requis, fonctionne sur batterie, limite d'1 heure ;
  - copie du script dans `C:\ProgramData\UpdateStoreApps\` ;
  - option `-Uninstall`.
- Lanceurs `.bat` par double-clic : `Update-StoreApps.bat`, `Installer-au-demarrage.bat`, `Desinstaller-du-demarrage.bat`.
