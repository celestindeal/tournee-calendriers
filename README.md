# Tournée calendriers – amicale des pompiers

Application web installable sur iPhone pour suivre la **tournée des calendriers des pompiers**. On touche une maison sur la carte, toute sa parcelle prend une couleur, et l'on voit d'un coup d'œil ce qui est fait et ce qui reste à faire.

**Communes couvertes** (Loire) : Saint-Héand (42234), Aveizieux (42010), Saint-Bonnet-les-Oules (42206), La Gimond (42100), Fontanès (42096), La Fouillouse (42097).

| Environnement | Adresse | Pour qui |
| --- | --- | --- |
| **Production** | https://celestindeal.github.io/tournee-calendriers/ | L'app utilisée pendant la tournée |
| **Test** | https://celestindeal.github.io/tournee-calendriers/test/ | Les essais, avant la mise en production |

- **0 €** : pas de serveur, pas d'abonnement, pas de compte développeur Apple.
- **Toutes les données restent sur le téléphone.** Rien n'est envoyé sur Internet.
- Documents de référence : le cahier des charges (Google Doc dans le dossier du projet) et l'architecture technique détaillée ([docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)).

---

## 1. Comment fonctionne l'application

### La carte et les statuts

La carte montre les **5 776 parcelles cadastrales bâties** des 6 communes. Les bâtiments y sont dessinés par-dessus le fond OpenStreetMap. L'app s'ouvre sur le bourg de Saint-Héand ; on rejoint les autres communes en déplaçant la carte, ou avec « Me localiser ».

1. **Toucher une maison** ouvre un panneau en bas de l'écran, avec l'adresse, la commune et la surface du terrain.
2. **Choisir un statut** : toute la parcelle (maison + terrain) prend sa couleur, et le panneau se ferme.

| Couleur | Statut | Signification |
| --- | --- | --- |
| Gris | Non visité | Jamais passé (état de départ) |
| 🟩 Vert | Fait – acheté | Calendrier vendu |
| 🟧 Orange | À repasser | Absent, à revoir |
| 🟥 Rouge | Fait – refus | Ne pas repasser |
| 🟦 Bleu | Non concerné | Local vide, bâtiment non habité… |

- Une parcelle a **un seul statut**, même si elle porte plusieurs bâtiments (maison, garage, grange…).
- Une erreur de doigt ? Toucher à nouveau la maison et choisir un autre statut, ou « Remettre en non visité ».
- **Vue de loin**, seules les parcelles déjà colorées sont dessinées, pour que l'iPhone reste fluide. Le message « Zoomez pour voir et toucher les maisons » s'affiche alors.
- Le **compteur** en haut indique par exemple « 132 / 480 faits (27 %) – 45 à repasser ». Un refus compte comme « fait » ; les parcelles « non concerné » ne comptent pas dans le total.

### Les autres fonctions

| Fonction | Où | Ce qu'elle fait |
| --- | --- | --- |
| **Itinéraire** | Icône ➦ à côté de l'adresse, dans le panneau | Propose Plans (Apple), Google Maps ou Waze pour aller jusqu'à la maison (coordonnées du bâtiment principal, même sans adresse connue). |
| **Mémos** | Bouton « Mémos » dans le panneau | Étiquettes à cocher : chien, pas de démarchage, mot laissé ; passer plutôt le matin / midi / soir / week-end ; un jour précis. Pas de texte libre (RGPD). Gardés d'une année sur l'autre. |
| **Filtre** | Sous le compteur | Toutes / Non visitées / À repasser : la carte n'affiche que les parcelles choisies. |
| **Listes** | Icône ☷ à côté du menu | « À repasser » et « Non visitées », par commune et par rue, avec date, mémos et itinéraire. Toucher une maison la montre sur la carte. |
| **Recherche** | Loupe à côté des listes | Taper un numéro, une rue ou une commune (« 12 prevert », « eglise fouillouse »), sans se soucier des accents. Toucher une adresse la montre sur la carte. Le texte tapé n'est pas enregistré. |
| **Nouvelle campagne** | Menu ☰ → Campagne | Une campagne par année : exporter, puis commencer l'année suivante. Toutes les maisons repassent en « non visité » ; l'ancienne campagne reste consultable (« En 2026 : acheté ») ; les mémos sont gardés. Seules les 2 dernières campagnes sont conservées. |
| **Me localiser** | Bouton rond en bas à droite | Point bleu à votre position. Le GPS n'est demandé qu'à l'appui, et se coupe quand l'app passe en arrière-plan. |
| **Exporter la tournée** | Menu ☰ | Crée un fichier de sauvegarde, à enregistrer dans Fichiers ou iCloud Drive. La date du dernier export s'affiche, en rouge s'il date de plus de 2 jours. |
| **Importer une sauvegarde** | Menu ☰ | Remplace les statuts par ceux d'un fichier, après confirmation. |
| **Annuler le dernier import** | Menu ☰ | Remet la tournée telle qu'elle était juste avant l'import. |
| **Diagnostic** | Menu ☰ | Version, état du stockage et du mode hors-ligne, dernières erreurs. Le bouton « Copier le diagnostic » permet de signaler un problème. |

### Hors-ligne

Après une première ouverture avec du réseau, l'app **fonctionne sans réseau** : carte des parcelles, statuts, compteur. Le fond de carte OpenStreetMap s'affiche pour les zones déjà vues ; ailleurs, le fond est gris neutre.

### Où sont les données ?

- Les statuts sont enregistrés **immédiatement**, à chaque toucher, dans le stockage du navigateur de l'iPhone (IndexedDB).
- ⚠️ L'app doit être **installée sur l'écran d'accueil** (Safari → Partager → « Sur l'écran d'accueil ») et **toujours ouverte depuis son icône**. Un onglet Safari a un stockage séparé, que iOS peut effacer. Un encadré jaune le rappelle si l'app est ouverte dans un onglet.
- ⚠️ **Supprimer l'icône efface toutes les données.** Pendant la tournée, faites un **export chaque soir**.
- Seuls sont enregistrés l'identifiant de la parcelle, son statut, la date, et les mémos cochés. Pas de nom, pas de texte libre (RGPD). Les statuts des campagnes passées ne sont gardés que pour les 2 dernières années.

### Mises à jour

Quand une nouvelle version est publiée, l'app la télécharge toute seule en arrière-plan. Elle s'applique **à l'ouverture suivante** de l'app. Les statuts ne sont jamais effacés par une mise à jour.

---

## 2. Déployer

### Les deux environnements

| | Production | Test |
| --- | --- | --- |
| Branche git | `main` | `test` |
| Adresse | `…/tournee-calendriers/` | `…/tournee-calendriers/test/` |
| Icône sur l'iPhone | « Tournée » (rouge) | « **TEST** » (orange) |
| Repère dans l'app | aucun | bandeau orange « VERSION DE TEST » |
| Base de données | `tournee.db` | `tournee-test.db` |

Les deux apps peuvent être installées côte à côte sur le même iPhone : **leurs données sont séparées**.

### Le principe

La publication est **automatique**. À chaque `git push` sur `main` ou sur `test`, le workflow GitHub [.github/workflows/deployer.yml](.github/workflows/deployer.yml) :

1. analyse et teste la branche poussée. **Si un test échoue, rien n'est publié** ;
2. compile la production (branche `main`) et le test (branche `test`) ;
3. publie les deux ensemble sur GitHub Pages. GitHub Pages ne publie qu'un seul site par dépôt, d'où ce double build.

Le déploiement prend environ 5 minutes. Pour le suivre : onglet **Actions** du dépôt sur GitHub, ou :

```bash
gh run watch
```

### Livrer une modification

**Étape 1 — développer sur la branche `test`**

```bash
git switch test
```

Faire les modifications, vérifier les tests (voir la partie 3), puis :

```bash
git add -A
```
```bash
git commit -m "Description de la modification"
```
```bash
git push
```

→ Le site de **test** est mis à jour ; la production ne bouge pas.

**Étape 2 — essayer sur l'iPhone avec l'app TEST** (voir la partie 3).

**Étape 3 — mettre en production, une fois l'essai validé**

```bash
git switch main
```
```bash
git merge --ff-only test
```
```bash
git push
```
```bash
git switch test
```

→ La **production** est mise à jour ; l'app de la tournée se met à jour à l'ouverture suivante.

`--ff-only` garantit que la production devient **exactement** ce qui a été essayé sur test. Si la commande refuse, c'est que `main` a reçu entre-temps un commit qui n'est pas dans `test` : ne rien forcer, et regarder ce qui s'est passé.

### Revenir en arrière

Si une version mise en production pose problème, on annule les commits de la livraison et on republie. L'annulation crée de nouveaux commits : l'historique reste intact, et rien n'est perdu.

1. Repérer le dernier commit de la version qui fonctionnait :

```bash
git switch main
```
```bash
git log --oneline -10
```

2. Annuler tout ce qui a été livré depuis, en remplaçant `abc1234` par l'identifiant repéré à l'étape 1 :

```bash
git revert --no-edit abc1234..HEAD
```
```bash
git push
```

La production revient à la version précédente en quelques minutes. La branche `test` garde la version annulée, pour qu'on puisse la corriger.

### Mettre à jour les données du cadastre

Le fichier [assets/data/parcelles.json](assets/data/parcelles.json) est **généré**, il ne se modifie pas à la main. Pour le regénérer, par exemple avec un nouveau millésime du cadastre :

```bash
dart run tool/preparer_donnees.dart --retelecharger
```

- **Communes** : par défaut, les 6 communes de la tournée. Pour en ajouter ou en retirer, passer la liste complète des codes INSEE, séparés par des virgules (la première commune sert de vue de départ) :

```bash
dart run tool/preparer_donnees.dart --insee 42234,42010,42206,42100,42096,42097
```

- Chaque commune est traitée séparément : ajouter une commune ne change pas les identifiants des autres.
- Sources : cadastre Etalab (bâtiments et parcelles) et Base Adresse Nationale, sous Licence Ouverte 2.0.
- Autres options : `--surface-min` (20 m² par défaut), `--types` (`01,03`), `--distance-max` (60 m). Le détail est en tête du script [tool/preparer_donnees.dart](tool/preparer_donnees.dart).
- Les fichiers bruts sont téléchargés dans `donnees_brutes/`, qui est ignoré par git.
- Le test [test/data/parcelles_source_test.dart](test/data/parcelles_source_test.dart) vérifie le nombre de parcelles par commune et la version du fichier : il faut le mettre à jour après une regénération.
- ⚠️ À faire **entre deux campagnes** : les identifiants des parcelles sont officiels et stables, mais une parcelle découpée ou fusionnée par le cadastre perd son statut.

### Réglages GitHub (déjà faits, pour mémoire)

- **Settings → Pages** : source « GitHub Actions ».
- **Settings → Environments → github-pages** : les branches `main` et `test` sont autorisées à publier.

---

## 3. Tester

### 3.1 Prérequis sur le PC

- **Flutter 3.47.9**, installé dans `C:\flutter\flutter`. Ajouter `C:\flutter\flutter\bin` au `PATH` de Windows pour pouvoir taper `flutter` et `dart`.
- **Git** et **GitHub CLI** (`gh`), connectés au compte GitHub.
- Récupérer les dépendances une première fois :

```bash
flutter pub get
```

### 3.2 Tests automatiques

Environ 80 tests couvrent :
- les statuts, le compteur et l'enregistrement ;
- le report de l'ancien suivi par bâtiment ;
- l'export et l'import ;
- le GPS, les pages Menu et Diagnostic ;
- le vrai fichier de parcelles (nombre de parcelles par commune).

```bash
flutter test
```

Analyse du code (erreurs, bonnes pratiques) :

```bash
dart analyze
```

> ⚠️ `flutter analyze` lancé depuis **PowerShell** plante à cause du « é » de « Tournée » dans le chemin du dossier. C'est un bug de l'outil : utiliser `dart analyze` depuis **Git Bash**.

Ces mêmes vérifications sont relancées par GitHub à chaque `push`.

### 3.3 Essayer la version de production sur le PC

Le mode développement de Flutter (`flutter run -d web-server`) reste bloqué au démarrage sans l'extension Chrome « Dart Debug ». Le plus simple est de compiler la vraie version et de la servir en local :

```bash
flutter build web --release --no-web-resources-cdn
```
```bash
dart run tool/generer_sw.dart --environnement prod
```
```bash
dart run tool/servir_web.dart
```

Puis ouvrir http://localhost:8080 dans Chrome. Pour voir l'app comme sur un téléphone : `F12`, puis l'icône « téléphone » (Ctrl+Maj+M).

**Tester le hors-ligne sur le PC** :
1. Ouvrir l'app deux fois, pour laisser le service worker se mettre en place.
2. Arrêter `servir_web.dart` (Ctrl+C).
3. Recharger la page : l'app doit démarrer quand même.

Pour essayer la version **test** en local, compiler avec `--dart-define=ENV=test` et générer le service worker avec `--environnement test`.

### 3.4 Essayer l'environnement de test sur l'iPhone

À faire après chaque `git push` sur `test`, une fois le déploiement terminé.

**Installer l'app TEST** (une seule fois) :
1. Dans **Safari**, ouvrir https://celestindeal.github.io/tournee-calendriers/test/.
2. Vérifier que le **bandeau orange « VERSION DE TEST »** est affiché. S'il manque, recharger la page une fois.
3. Partager → « Sur l'écran d'accueil » : l'icône s'appelle **TEST**.

**Récupérer la nouvelle version** : ouvrir l'app TEST, attendre quelques secondes, la fermer complètement (balayer vers le haut), puis la rouvrir. Menu → Diagnostic indique le numéro de version, c'est-à-dire le commit.

**Essayer avec les vraies données de la tournée**, sans risque pour elles :
1. Dans l'app **Tournée** (production) : Menu → Exporter la tournée → Enregistrer dans Fichiers.
2. Dans l'app **TEST** : Menu → Importer une sauvegarde → choisir ce fichier → Remplacer.

**Liste de vérification** :

- [ ] La carte s'affiche sur le bourg de Saint-Héand, avec le bandeau orange.
- [ ] Toucher une maison ouvre le panneau, avec la bonne adresse et la bonne commune.
- [ ] Un statut colore toute la parcelle, et le compteur se met à jour.
- [ ] Les autres communes s'affichent quand on déplace la carte, et la carte reste fluide.
- [ ] Après fermeture et réouverture de l'app, les statuts sont toujours là.
- [ ] En **mode Avion**, l'app s'ouvre et l'on peut changer un statut.
- [ ] « Me localiser » affiche le point bleu.
- [ ] Export, puis import, puis « Annuler le dernier import » fonctionnent.
- [ ] Menu → Diagnostic affiche « Ouverte depuis l'écran d'accueil : oui » et un service worker actif.
- [ ] L'app **Tournée** (production) n'a pas changé.

Si tout est bon : mettre en production (partie 2, étape 3).

### 3.5 Vérifier la production après une mise en production

1. Ouvrir l'app **Tournée**, attendre quelques secondes, la fermer puis la rouvrir.
2. Menu → Diagnostic : le numéro de version correspond au dernier commit de `main`.
3. Vérifier que les statuts déjà saisis sont toujours là.

---

## Dépannage

| Problème | Solution |
| --- | --- |
| L'adresse `/test/` affiche l'app de production | Recharger la page une fois : l'ancien service worker de production est remplacé au premier passage. |
| La nouvelle version n'apparaît pas sur l'iPhone | Ouvrir l'app, attendre quelques secondes, la fermer complètement et la rouvrir. |
| La carte est vide, avec « Zoomez pour voir… » | Normal vue de loin : zoomer sur un village. Les parcelles déjà colorées restent visibles. |
| iOS redemande l'autorisation de localisation | Limite connue des apps web sur iPhone. Réglages → Confidentialité et sécurité → Service de localisation → Sites web Safari. |
| Le déploiement GitHub échoue | Onglet Actions du dépôt : l'étape en rouge indique la cause, souvent un test qui ne passe plus. |
| Un fichier du projet est revenu à une ancienne version | Le dossier est synchronisé par Google Drive, qui peut écraser un fichier non commité. Commiter régulièrement, ou déplacer le projet dans un dossier local. |
| Signaler un problème | Dans l'app : Menu → Diagnostic → « Copier le diagnostic », puis coller le texte dans un message. |

## Organisation du code

```
lib/            Code de l'app (Flutter)
  models/       Parcelle, commune, statut, état, compteur…
  data/         Chargement des parcelles, base IndexedDB, export / import
  state/        Logique : tournée, GPS, report de l'ancien suivi
  ui/           Écrans : carte, panneau, menu, diagnostic
  platform/     Fonctions du navigateur (GPS, stockage, service worker)
test/           Tests automatiques
tool/           Scripts : données du cadastre, service worker, serveur local
web/            Page d'accueil, manifeste, démarrage de l'app
assets/data/    parcelles.json (généré)
docs/           Architecture technique détaillée
```
