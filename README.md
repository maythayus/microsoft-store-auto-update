# Microsoft Store Auto-Update

Scripts PowerShell / Batch pour **vérifier et forcer la mise à jour des applications du Microsoft Store**, à la main ou **automatiquement à chaque ouverture de session Windows**.

## Fonctionnement

Le script `Update-StoreApps.ps1` se déroule en 5 étapes :

1. **Inventaire** : liste les applications Store installées et leur version actuelle.
2. **Store CLI** (`store.exe`, méthode principale) : vérifie et installe les mises à jour de **toutes** les applications Store.
   ```powershell
   store updates --apply true
   ```
3. **Scan du Store** (CIM/MDM, équivalent du bouton « Obtenir les mises à jour »), en complément ou en secours si `store.exe` est absent :
   ```powershell
   Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" |
       Invoke-CimMethod -MethodName UpdateScanMethod
   ```
4. **winget** (source `msstore`), via le module officiel [`Microsoft.WinGet.Client`](https://www.powershellgallery.com/packages/Microsoft.WinGet.Client) installé automatiquement, pour les applications que winget reconnaît. Repli sur `winget upgrade --all` si le module ne peut pas être installé.
5. **Bilan** : attend la fin des installations lancées par le Store (5 minutes max par défaut), puis affiche les versions avant / après.

### Pourquoi `store.exe` ?

`store.exe` est l'outil en ligne de commande officiel du Microsoft Store (en préversion, inclus dans les versions récentes du Store sur Windows 11). Il voit les mises à jour de toutes les applications Store, alors que winget ne reconnaît souvent qu'une petite partie d'entre elles. Commandes utiles :

```powershell
store updates                              # liste les mises à jour disponibles
store updates --apply true                 # installe toutes les mises à jour
store updates --filter "Photos" --apply true   # une seule application
store installed                            # applications installées
```

Les installations se font en arrière-plan par le Store : une application ouverte est mise à jour à sa fermeture.

## Prérequis

- Windows 10 / 11 (`store.exe` : Windows 11 avec un Microsoft Store récent ; sinon le script utilise les méthodes de secours)
- Droits administrateur (le script se relance automatiquement en admin)
- [winget](https://learn.microsoft.com/windows/package-manager/winget/) (paquet « App Installer » du Store) pour l'étape 4

## Fichiers

| Fichier | Rôle |
|---|---|
| `Update-StoreApps.ps1` | Vérifie les versions et lance les mises à jour (options ci-dessous). |
| `Update-StoreApps.bat` | Mise à jour normale par double-clic. |
| `Update-StoreApps-Force.bat` | Mise à jour **forcée** par double-clic. |
| `Reparer-et-mettre-a-jour.bat` | **Réparation** du Store puis mise à jour forcée. |
| `Verifier-versions.bat` | Affiche les versions et les mises à jour disponibles, **sans rien installer**. |
| `Install-StartupTask.ps1` | Installe la tâche planifiée au démarrage (`-Force`, `-Uninstall`). |
| `Installer-au-demarrage.bat` | Installe la tâche au démarrage (mode normal). |
| `Installer-au-demarrage-Force.bat` | Installe la tâche au démarrage en mode **forcé**. |
| `Desinstaller-du-demarrage.bat` | Supprime la tâche. |

## Options de `Update-StoreApps.ps1`

| Option | Effet |
|---|---|
| *(aucune)* | Inventaire, mises à jour (store.exe, scan CIM, winget), bilan. |
| `-CheckOnly` | Affiche les versions installées et les mises à jour disponibles, n'installe rien. |
| `-Force` | Redémarre le service d'installation du Store (`InstallService`) pour débloquer les téléchargements en attente, puis met à jour avec `winget --force` en incluant les paquets épinglés. |
| `-Repair` | Répare le Store avant les mises à jour : vidage du cache (`wsreset.exe`) et réenregistrement de l'application Microsoft Store. |
| `-WaitMinutes <n>` | Durée maximale d'attente de la fin des installations (défaut `5`, `0` = pas d'attente). |
| `-Silent` | Mode démarrage : sans pause, sans ouvrir le Store, journal dans un fichier. |

Les options se combinent, par exemple `-Force -Silent` ou `-Repair -Force`.

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

Après une mise à jour du script, relancer l'installeur pour remplacer la copie installée.

### Désinstallation

Double-cliquer sur **`Desinstaller-du-demarrage.bat`**, ou :

```powershell
.\Install-StartupTask.ps1 -Uninstall
```

## Limites

- `store.exe` est en préversion : il lance les installations mais c'est le Store qui les termine, en arrière-plan.
- Certaines applications liées au matériel (par exemple Killer Control Center) ne sont mises à jour que lorsque le Store en propose une version pour votre appareil.
- La tâche s'exécute dans votre session utilisateur (nécessaire pour `store.exe`, winget et les applications installées par utilisateur).

## Licence

[MIT](LICENSE)
