# Microsoft Store Auto-Update

Scripts PowerShell / Batch pour **mettre à jour les applications du Microsoft Store** en une commande, à la main ou **automatiquement à chaque ouverture de session Windows**.

## Fonctionnement

Le script `Update-StoreApps.ps1` combine deux méthodes :

1. **Scan de mises à jour du Store** (équivalent du bouton « Obtenir les mises à jour ») via l'interface CIM/MDM :
   ```powershell
   Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" |
       Invoke-CimMethod -MethodName UpdateScanMethod
   ```
2. **winget** sur la source `msstore` :
   ```powershell
   winget upgrade --all --source msstore --silent --accept-source-agreements --accept-package-agreements
   ```

Les deux sont complémentaires : winget ne voit pas toutes les applications du Store, et le scan CIM délègue le téléchargement au Store en arrière-plan.

## Prérequis

- Windows 10 / 11
- Droits administrateur (le script se relance automatiquement en admin)
- [winget](https://learn.microsoft.com/windows/package-manager/winget/) (paquet « App Installer » du Store) pour la méthode 2

## Fichiers

| Fichier | Rôle |
|---|---|
| `Update-StoreApps.ps1` | Lance les mises à jour. Option `-Silent` : sans fenêtre, sans pause, journal dans un fichier. |
| `Update-StoreApps.bat` | Lance le `.ps1` par double-clic (contourne l'ExecutionPolicy). |
| `Install-StartupTask.ps1` | Installe la tâche planifiée au démarrage (`-Uninstall` pour la retirer). |
| `Installer-au-demarrage.bat` | Double-clic pour installer la tâche au démarrage. |
| `Desinstaller-du-demarrage.bat` | Double-clic pour supprimer la tâche. |

## Utilisation

### Mise à jour manuelle

Double-cliquer sur **`Update-StoreApps.bat`**, ou :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Update-StoreApps.ps1
```

### Au démarrage de Windows

Garder tous les fichiers dans le même dossier puis double-cliquer sur **`Installer-au-demarrage.bat`** (une seule validation UAC).

L'installation :

- copie le script dans `C:\ProgramData\UpdateStoreApps\` (le dossier d'origine peut ensuite être supprimé) ;
- crée la tâche planifiée **« Mise a jour apps Microsoft Store »** :
  - déclenchée à l'ouverture de session, avec un délai de 2 minutes ;
  - exécutée avec les privilèges les plus élevés, sans fenêtre ni invite UAC ;
  - uniquement si le réseau est disponible, aussi sur batterie ;
  - limitée à 1 heure.

Tester sans redémarrer (PowerShell admin) :

```powershell
Start-ScheduledTask -TaskName "Mise a jour apps Microsoft Store"
```

Journal de la dernière exécution : `C:\ProgramData\UpdateStoreApps\derniere-execution.log`

Après une modification de `Update-StoreApps.ps1`, relancer l'installeur pour mettre à jour la copie installée.

### Désinstallation

Double-cliquer sur **`Desinstaller-du-demarrage.bat`**, ou :

```powershell
.\Install-StartupTask.ps1 -Uninstall
```

## Notes

- Le scan CIM ne fait que *déclencher* les mises à jour : le Store peut encore travailler quelques minutes après la fin du script.
- La tâche s'exécute dans votre session utilisateur (nécessaire pour winget et les applications du Store installées par utilisateur).

## Licence

[MIT](LICENSE)
