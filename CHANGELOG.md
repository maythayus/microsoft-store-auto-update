# Notes de version

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
