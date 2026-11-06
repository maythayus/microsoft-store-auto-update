# Microsoft Store Auto-Update

Scripts PowerShell / Batch pour **mettre à jour les applications du Microsoft Store** en une commande, à la main ou **automatiquement à chaque ouverture de session Windows**.

## Fonctionnement

Le script `Update-StoreApps.ps1` se déroule en 4 étapes :

1. **Inventaire** : liste les applications Store installées et leur version actuelle.
2. **Scan de mises à jour du Store** (voir ci-dessous).
3. **Comparaison des versions** avec winget (version installée / version disponible), puis mise à jour de **chaque application qui a une mise à jour**.
4. **Bilan** : versions avant / après.

Les deux mécanismes de mise à jour utilisés :

1. **Scan de mises à jour du Store** (équivalent du bouton « Obtenir les mises à jour ») via l'interface CIM/MDM :
   ```powershell
   Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" |
       Invoke-CimMethod -MethodName UpdateScanMethod
   ```
2. **winget** sur la source `msstore`, via le module PowerShell officiel [`Microsoft.WinGet.Client`](https://www.powershellgallery.com/packages/Microsoft.WinGet.Client) (installé automatiquement au premier lancement) :
   ```powershell
   Get-WinGetPackage -Source msstore | Where-Object IsUpdateAvailable | ForEach-Object {
       Update-WinGetPackage -Id $_.Id -Source msstore -Mode Silent
   }
   ```
   Si le module ne peut pas être installé, le script se replie sur `winget upgrade --all --source msstore`.

Les deux sont complémentaires : winget ne voit pas toutes les applications du Store, et le scan CIM délègue le téléchargement au Store en arrière-plan.

## Prérequis

- Windows 10 / 11
- Droits administrateur (le script se relance automatiquement en admin)
- [winget](https://learn.microsoft.com/windows/package-manager/winget/) (paquet « App Installer » du Store) pour la méthode 2

## Fichiers

| Fichier | Rôle |
|---|---|
| `Update-StoreApps.ps1` | Vérifie les versions et lance les mises à jour (options ci-dessous). |
| `Update-StoreApps.bat` | Mise à jour normale par double-clic. |
| `Update-StoreApps-Force.bat` | Mise à jour **forcée** par double-clic. |
| `Verifier-versions.bat` | Affiche les versions et les mises à jour disponibles, **sans rien installer**. |
| `Install-StartupTask.ps1` | Installe la tâche planifiée au démarrage (`-Force`, `-Uninstall`). |
| `Installer-au-demarrage.bat` | Installe la tâche au démarrage (mode normal). |
| `Installer-au-demarrage-Force.bat` | Installe la tâche au démarrage en mode **forcé**. |
| `Desinstaller-du-demarrage.bat` | Supprime la tâche. |

## Options de `Update-StoreApps.ps1`

| Option | Effet |
|---|---|
| *(aucune)* | Inventaire, scan du Store, mise à jour des applications qui en ont une, bilan. |
| `-CheckOnly` | Affiche les versions installées et disponibles, n'installe rien. |
| `-Force` | Redémarre le service d'installation du Store (`InstallService`) pour débloquer les téléchargements en attente, puis met à jour avec `winget --force` en incluant les paquets épinglés. |
| `-Silent` | Mode démarrage : sans pause, sans ouvrir le Store, journal dans un fichier. |

Les options se combinent, par exemple `-Force -Silent`.

## Utilisation

### Mise à jour manuelle

Double-cliquer sur **`Update-StoreApps.bat`**, ou :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Update-StoreApps.ps1
```

### Au démarrage de Windows

Garder tous les fichiers dans le même dossier puis double-cliquer sur **`Installer-au-demarrage.bat`**, ou sur **`Installer-au-demarrage-Force.bat`** pour le mode forcé (une seule validation UAC).

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
