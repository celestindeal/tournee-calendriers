# Ajouter (ou modifier) une tournée

Dans l'app, chaque personne peut choisir **sa tournée** dans Menu → **Ma tournée**. La carte se cadre alors sur la tournée et dessine son contour en violet. Les maisons des autres tournées apparaissent estompées, mais restent modifiables.

Les contours des tournées viennent d'une carte **Google My Maps**. Ajouter une tournée prend une dizaine de minutes : on dessine le contour, on l'exporte, on lance une commande, puis on publie.

> Rien ne change pour les données de la tournée (maisons cochées, mémos) : on ne touche qu'au dessin des contours.

---

## 1. Dessiner la tournée dans Google My Maps

1. Ouvrez la carte qui contient déjà la **Tournée n°7** sur https://www.google.com/mymaps, depuis un ordinateur.
   Gardez **toutes les tournées dans cette même carte** : l'export doit toutes les contenir (voir l'étape 3).
2. Cliquez sur l'outil **« Tracer une ligne »**, puis sur **« Ajouter une ligne ou une forme »**.
3. Cliquez point par point autour de la tournée. Pour **fermer la forme**, cliquez sur le tout premier point : la zone se remplit de couleur.
4. Dans la fenêtre qui s'ouvre, nommez la forme avec son numéro, par exemple **`Tournée n°3`**.
   C'est le **numéro** que l'app lit dans le nom. `Tournée n°3`, `T3` ou `Tournée 3` conviennent. Le nom ne doit contenir qu'un seul nombre.

Bon à savoir :
- Une maison fait partie d'une tournée si le **centre de son terrain** est à l'intérieur du contour. Pour une maison en limite, passez le trait franchement d'un côté ou de l'autre.
- Une tournée peut avoir **plusieurs morceaux** : donnez simplement le même numéro à chaque forme.
- Les repères (épingles) et les formes sans numéro sont ignorés.
- La carte de l'app ne couvre que les 6 communes chargées : Saint-Héand, Aveizieux, Saint-Bonnet-les-Oules, La Gimond, Fontanès et La Fouillouse. Une tournée en dehors n'aurait pas de maisons.

## 2. Exporter la carte en KML

1. Dans My Maps, cliquez sur le menu **⋮**, à côté du titre de la carte.
2. Choisissez **« Exporter au format KML/KMZ »**.
3. Dans la liste, laissez **« Carte entière »**.
4. Cochez **« Exporter au format .KML plutôt qu'au format .KMZ »**.
5. Cliquez sur **Télécharger**. Le fichier arrive dans `Téléchargements`, par exemple `Tournées.kml`.

## 3. Mettre les contours dans l'app

Ouvrez **PowerShell**, ou le terminal de VS Code, dans le dossier du projet, puis lancez la commande ci-dessous. Remplacez le chemin du fichier par le vôtre, en gardant les guillemets.

```powershell
& "C:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe" run tool/preparer_tournees.dart "C:\Users\admin\Downloads\Tournées.kml"
```

La commande affiche les tournées trouvées, par exemple :

```
Tournée n°3 → tournée 3 (40 points)
Tournée n°7 → tournée 7 (52 points)
assets/data/tournees.json : 2 tournée(s).
```

> ⚠️ Le fichier des tournées est **entièrement remplacé** par ce que contient l'export. Si une tournée manque dans la liste affichée, c'est qu'elle n'est pas dans la carte exportée : elle disparaîtrait de l'app. Ajoutez-la à la carte My Maps et recommencez l'export.
> Si les tournées sont dans plusieurs cartes, donnez tous les fichiers d'un coup : `… preparer_tournees.dart "carte1.kml" "carte2.kml"`.

**Facultatif** : pour savoir combien de maisons compte chaque tournée, lancez les tests ; le nombre de maisons de la tournée 7 s'affiche.

```powershell
& "C:\flutter\flutter\bin\flutter.bat" test test/state/tournees_test.dart
```

## 4. Publier sur l'app TEST

Enregistrez tout de suite le changement dans Git. Google Drive peut sinon remettre une ancienne version du fichier.

```powershell
git add assets/data/tournees.json
git commit -m "Tournées : ajout de la tournée n°3"
git push origin test
```

GitHub reconstruit l'app TEST en 3 à 5 minutes. Pour suivre l'avancement, ouvrez l'onglet **Actions** du dépôt sur github.com : la ligne passe au vert quand c'est en ligne.

Ensuite, sur l'iPhone, dans l'app **TEST** :
1. Fermez complètement l'app, puis rouvrez-la pour recevoir la nouvelle version.
2. Allez dans Menu → **Ma tournée** : la nouvelle tournée apparaît, avec son nombre de maisons.
3. Choisissez-la : la carte se cadre dessus et dessine le contour. Vérifiez quelques maisons en limite.

## 5. Mettre en production

Quand tout est bon dans l'app TEST :

```powershell
git push origin test:main
```

Cette commande envoie la branche `test` telle quelle sur `main`, c'est-à-dire la production, sans changer de branche sur le PC. GitHub republie l'app de la tournée en 3 à 5 minutes. Les téléphones la reçoivent à la prochaine ouverture avec du réseau. Le choix « Ma tournée » de chacun est conservé.

---

## En cas de problème

| Ce qui se passe | Que faire |
| --- | --- |
| `0 tournée(s)` | Les formes n'ont pas de numéro dans leur nom, ou ce sont des épingles. Renommez-les « Tournée n°X ». |
| Une tournée a trop peu de points ou n'apparaît pas | La forme n'est pas fermée : dans My Maps, refermez-la en cliquant sur son premier point. |
| `git push` est refusé | Faites d'abord `git pull origin test`, puis recommencez le `git push`. |
| La tournée n'apparaît pas sur l'iPhone | Fermez complètement l'app et rouvrez-la avec du réseau. Vérifiez aussi que la publication est verte dans l'onglet Actions de GitHub. |
| `Format de tournées inconnu` au démarrage de l'app | Le fichier `assets/data/tournees.json` a été modifié à la main. Relancez la commande de l'étape 3. |

Vous pouvez aussi simplement envoyer le fichier `.kml` à Claude, qui fera les étapes 3 à 5.
