# Architecture – Appli tournée calendriers (MVP)

*Version 1 – 11/11/2026 – Flutter 3.47.9 / Dart 3.13.7*

Ce document décrit comment l'application est construite. Il découle du cahier des charges v2 (MVP 100 % local, 0 €) : une PWA Flutter web, sans serveur applicatif, utilisée sur un seul iPhone.

---

## 1. Vue d'ensemble

```
                  ┌──────────── une seule fois, sur le PC ─────────────┐
 cadastre Etalab ─┤ tool/preparer_donnees.dart                         │
 (GeoJSON)        │  filtre surface + rattachement adresse BAN         ├─► assets/data/batiments.json
 BAN (adresses) ──┤  simplification + id stable                        │     (embarqué dans l'app)
                  └────────────────────────────────────────────────────┘

 ┌──────────────────────── iPhone (PWA sur l'écran d'accueil) ─────────────────────┐
 │                                                                                 │
 │  UI (lib/ui)  ──écoute──►  TourneeController / PositionController (lib/state)   │
 │       │                         │                     │                         │
 │       │ actions                 ▼                     ▼                         │
 │       └──────────────►  TourneeRepository        geolocator                     │
 │                         (sembast → IndexedDB)    (navigator.geolocation)        │
 │                                                                                 │
 │  sw.js (notre service worker) : met en cache l'app + batiments.json + CanvasKit │
 └─────────────────────────────────────────────────────────────────────────────────┘
          ▲ une seule fois (puis mises à jour)            ▲ quand il y a du réseau
   GitHub Pages (fichiers statiques, HTTPS)        tuiles OpenStreetMap (fond de carte)
```

Principes :
- **Les bâtiments sont en lecture seule** et embarqués dans l'app. Seuls les **statuts** sont écrits sur l'iPhone.
- **Chaque toucher est enregistré immédiatement** dans IndexedDB (F4). Rien d'important ne reste uniquement en mémoire : iOS peut tuer une PWA en arrière-plan à tout moment.
- **Aucune donnée de tournée ne sort du téléphone**, sauf par l'export manuel (F8).

---

## 2. Packages

Versions relevées sur pub.dev le 11/11/2026. Toutes supportent la plateforme web.

| Rôle | Package | Version | Pourquoi ce choix |
| --- | --- | --- | --- |
| Carte | `flutter_map` | 8.3.2 | Carte en Flutter pur (pas de SDK natif), `PolygonLayer` avec détection du toucher (`hitNotifier`) |
| Coordonnées | `latlong2` | 0.10.1 | Type `LatLng` utilisé par flutter_map |
| Stockage local | `sembast` + `sembast_web` | 3.10.1 / 2.4.7 | Base clé → document en Dart pur, stockée dans **IndexedDB** sur le web (exigence du cahier des charges), très bien maintenue (mise à jour le 09/11/2026), export JSON trivial |
| GPS | `geolocator` | 14.1.2 | Utilise `navigator.geolocation` sur le web ; même API si un jour on fait une app native |
| Export | `share_plus` | 13.3.1 | Sur iPhone, ouvre la feuille de partage iOS (Web Share API avec fichier) → « Enregistrer dans Fichiers » / iCloud Drive |
| Import | `file_picker` | 13.3.3 | Ouvre le sélecteur de fichiers iOS (Fichiers / iCloud Drive) |
| Interop navigateur | `web` | (dernière) | Accès à `navigator.storage.persist()` ; `dart:html` est obsolète |

Commande d'installation (à lancer au moment d'implémenter) :

```bash
flutter pub add flutter_map latlong2 sembast sembast_web geolocator share_plus file_picker web
```

**Écartés et pourquoi :**
- `shared_preferences` : sur le web, il utilise `localStorage` (synchrone, limité, purgé dans les mêmes conditions qu'IndexedDB). Ce n'est pas ce que demande le cahier des charges.
- `drift` / `sqflite` : SQLite sur le web exige un fichier `sqlite3.wasm` et un worker. C'est trop lourd pour ~1 000 enregistrements clé → statut.
- `hive` : n'est plus maintenu. `hive_ce` (son fork maintenu) serait une alternative acceptable à sembast.
- `flutter_map_location_marker` : pratique, mais il dépend aussi d'une boussole, absente sur le web. Un `CircleLayer` maison de 20 lignes suffit pour le point bleu.
- `flutter_riverpod`, `provider`, `bloc` : inutiles à cette taille (voir §5).
- Plugin de cache de tuiles hors-ligne : la politique d'OpenStreetMap interdit le pré-téléchargement massif de tuiles, et le cahier des charges accepte un fond neutre hors-ligne.

---

## 3. Structure des dossiers

Organisation « par couche », la plus simple à suivre pour un petit projet :

```
lib/
  main.dart                   Démarrage : ouvre la base, charge les bâtiments, lance l'app
  app.dart                    MaterialApp, thème, police embarquée
  models/
    statut.dart               enum Statut + couleur + libellé
    batiment.dart             Batiment (id, contour, centre, adresse, surface)
    etat_batiment.dart        EtatBatiment (id bâtiment, statut, date)
    avancement.dart           Compteurs pour la barre F5
  journal.dart                Dernières erreurs (page Diagnostic)
  data/
    batiments_source.dart     Lit assets/data/batiments.json
    tournee_repository.dart   Lecture/écriture des états dans sembast (IndexedDB)
    export_service.dart       Format d'export JSON v1, validation à l'import
  state/
    tournee_controller.dart   États, sélection, filtre, annulation, compteurs
    position_controller.dart  Flux GPS (démarré à la demande)
  platform/
    plateforme.dart           Interface « ce que dit le navigateur » (simulée dans les tests)
    navigateur.dart           Implémentation web (package:web) : installée ?, persist(), service worker
    gps.dart                  Flux de positions geolocator
  ui/
    carte_page.dart           Écran principal (carte + barre + bouton GPS)
    couche_batiments.dart     PolygonLayer coloré + détection du toucher
    couche_position.dart      Point bleu
    panneau_statut.dart       Panneau du bas : adresse + 5 gros boutons (F2)
    barre_avancement.dart     « 132 / 480 faits (27 %) – 45 à repasser » + légende (F5)
    menu_page.dart            Export, import, annuler l'import, diagnostic, sources
    diagnostic_page.dart      État de l'app et erreurs récentes, bouton « Copier »
    conseil_installation.dart Encadré « installez l'app » quand elle est ouverte dans un onglet
    formats.dart              Dates lisibles (« hier à 18h32 »)
assets/
  data/batiments.json         Généré par tool/preparer_donnees.dart (versionné dans git)
  fonts/                      Police embarquée (indispensable hors-ligne, voir §7.3)
tool/
  preparer_donnees.dart       Cadastre + BAN → assets/data/batiments.json
  generer_sw.dart             Après le build : écrit build/web/sw.js avec la liste des fichiers
web/
  index.html                  Écran de chargement, balises iOS
  flutter_bootstrap.js        Personnalisé : n'enregistre PAS le service worker Flutter
  manifest.json               Nom, icônes, start_url, display: standalone
tool/sw_modele.js             Modèle de notre service worker (hors de web/ pour ne pas être copié tel quel)
.github/workflows/deployer.yml  Tests + build + publication sur GitHub Pages à chaque push sur main
test/
  models/ data/ state/        Tests unitaires (statuts, compteurs, export/import, annulation)
```

Les scripts de `tool/` sont en Dart pour n'avoir qu'un seul langage dans le projet. Ils se lancent avec `dart run tool/xxx.dart`.

---

## 4. Modèle de données

### 4.1 Statut

```dart
enum Statut {
  nonVisite('Non visité', Color(0xFF9E9E9E)),   // gris – valeur par défaut, jamais stockée
  achete('Fait – acheté', Color(0xFF2E7D32)),   // vert
  aRepasser('À repasser', Color(0xFFEF6C00)),   // orange
  refus('Fait – refus', Color(0xFFC62828)),     // rouge
  nonConcerne('Non concerné', Color(0xFF1565C0)); // bleu

  const Statut(this.libelle, this.couleur);
  final String libelle;
  final Color couleur;
}
```

Les **noms** de l'enum (`achete`, `aRepasser`…) sont écrits dans la base et dans les exports. Ne jamais les renommer sans migration.

### 4.2 Bâtiment (lecture seule, embarqué)

```dart
class Batiment {
  final String id;                    // stable, voir ci-dessous
  final List<List<LatLng>> contours;  // une ou plusieurs parties, déjà simplifiées
  final LatLng centre;                // pour l'adresse et le recentrage
  final String? adresse;              // « 12 Rue Apollo », null si aucune adresse à moins de 60 m
  final double surfaceM2;
}
```

Le fichier `assets/data/batiments.json` est **généré** par `dart run tool/preparer_donnees.dart` (voir l'en-tête du script pour les options). Il est versionné dans git. Format compact :

```json
{
  "version": "2026-09-01-6c5672c1",
  "commune": { "insee": "42234", "nom": "Saint-Héand" },
  "sources": { "cadastre": "…millésime 2026-09-01…", "adresses": "…BAN du 2026-11-11…" },
  "parametres": { "types": ["01", "03"], "surfaceMinM2": 20, "distanceAdresseMaxM": 60 },
  "centre": [45.533883, 4.38225],
  "bbox": [[45.505327, 4.343518], [45.562438, 4.420981]],
  "batiments": [
    { "id": "u054gtt5m", "a": "7 Rue Jacques Prévert", "s": 136.6,
      "c": [45.514197, 4.379658],
      "p": [ [[45.51418, 4.37960], [45.51425, 4.37971], …] ] }
  ]
}
```

- **`id` stable** : le cadastre Etalab ne fournit **aucun identifiant** de bâtiment (vérifié). On utilise donc un géohash du centre du bâtiment (précision 9 ≈ 5 m), avec un suffixe `-2`, `-3`… en cas de doublon (3 cas à Saint-Héand). Si on régénère le fichier l'année suivante, les mêmes maisons gardent le même id, et un ancien export reste importable.
- `p` : liste de contours (un par partie du bâtiment), sans point de fermeture. Les cours intérieures (trous) sont ignorées : flutter_map les gère mal sur le web.
- Coordonnées arrondies à 6 décimales (≈ 0,1 m). Simplification Douglas-Peucker à 0,3 m.
- `version` = millésime du cadastre + empreinte du contenu. Le script est reproductible (même entrée → même version). Elle permet de détecter, à l'import, un export fait avec un autre jeu de bâtiments.

**Saint-Héand (42234), génération du 11/11/2026** :
- 4 423 bâtiments au cadastre, 2 457 gardés. Sont écartés les 1 364 de type 02 (bâti léger : abris, cabanons) et les 602 de moins de 20 m².
- 1 762 adresses BAN ; 95 % des bâtiments gardés ont une adresse à moins de 60 m. Dans les hameaux, une même adresse peut couvrir jusqu'à 11 bâtiments (ferme et dépendances) : ces dépendances seront marquées « non concerné ».
- Le fichier fait 519 Ko, 125 Ko une fois compressé pour le transfert. C'est bien plus que les ~480 maisons évoquées dans le cahier des charges, mais flutter_map le supporte sans problème.

### 4.3 État d'un bâtiment (écrit sur l'iPhone)

```dart
class EtatBatiment {
  final String batimentId;
  final Statut statut;
  final DateTime modifieLe;
}
```

Conforme au RGPD du cahier des charges : un id, un statut, une date. **Rien d'autre.**

### 4.4 Stockage sembast (IndexedDB)

Base `tournee.db`, deux « stores » :

| Store | Clé | Valeur | Remarque |
| --- | --- | --- | --- |
| `etats` | id du bâtiment | `{"s": "achete", "t": 1762850000000}` | **Absence = non visité.** Repasser en gris supprime l'enregistrement |
| `meta` | `"campagne"` | `{"debut": …, "versionBatiments": "2026-11-11-a1b2c3"}` | Sert à F11 et à l'export |

Le schéma est versionné (`version: 1` à l'ouverture de la base) pour permettre une migration propre en V2.

### 4.5 Format d'export (F8)

Nom du fichier : `tournee-2026-11-11-1832.json`

```json
{
  "format": "tournee-calendriers",
  "versionFormat": 1,
  "exporteLe": "2026-11-11T18:32:00Z",
  "versionBatiments": "2026-11-11-a1b2c3",
  "campagne": { "debut": "2026-11-01T09:00:00Z" },
  "etats": [ { "id": "u0m5k3h2q", "s": "achete", "t": 1762850000000 } ]
}
```

À l'import :
- on vérifie `format` et `versionFormat` ;
- on prévient si `versionBatiments` diffère, et on ignore les ids inconnus en les comptant ;
- on demande confirmation (« remplacer les 132 statuts actuels ? ») ;
- **avant d'écraser, on refait un export automatique**, pour qu'une fausse manipulation soit toujours rattrapable.

### 4.6 Compteurs (F5) – règle validée le 11/11/2026

- **Total** = bâtiments affichés − « non concerné »
- **Faits** = acheté + refus
- **À repasser** = à repasser
- Exemple : « 132 / 480 faits (27 %) – 45 à repasser »

> Décision du 11/11/2026 : un « refus » compte comme « fait ».

---

## 5. Gestion de l'état

**Choix : Flutter pur (`ChangeNotifier` + `ListenableBuilder`), sans package.**
Il y a un seul écran principal, deux sources d'état et un seul utilisateur. Riverpod ou Bloc ajouteraient des concepts à apprendre sans bénéfice ici. Si la V2 ajoute la synchronisation et plusieurs écrans, on pourra migrer vers Riverpod 3 sans toucher aux modèles ni au repository.

### 5.1 `TourneeController extends ChangeNotifier`

```dart
class TourneeController extends ChangeNotifier {
  TourneeController(this._repo, this.batiments);

  final TourneeRepository _repo;
  final List<Batiment> batiments;          // immuable
  final Map<String, EtatBatiment> _etats = {};
  final List<EtatBatiment?> _pileAnnulation = []; // 20 dernières actions, en mémoire

  String? selectionId;                     // bâtiment dont le panneau est ouvert
  Filtre filtre = Filtre.tous;             // tous | aRepasser | nonVisites (F9)

  Statut statutDe(String id);
  Avancement get avancement;               // recalculé à chaque changement (O(n), négligeable)
  List<Batiment> get batimentsVisibles;    // selon le filtre

  Future<void> charger();                  // lit IndexedDB au démarrage
  Future<void> changerStatut(String id, Statut s); // F2/F3/F4
  Future<void> annuler();                  // F10
  void selectionner(String? id);
  void changerFiltre(Filtre f);
  Future<void> nouvelleCampagne();         // F11 : export auto PUIS remise à zéro
}
```

Règles :
- `changerStatut` met d'abord à jour la mémoire et appelle `notifyListeners()`, pour que la couleur change instantanément. Il **écrit ensuite dans IndexedDB** (`await`). En cas d'échec d'écriture, on restaure l'ancien statut et on affiche un message : on ne doit jamais croire qu'une maison est enregistrée alors qu'elle ne l'est pas.
- La pile d'annulation reste en mémoire. Elle est perdue si iOS ferme l'app, ce qui est acceptable pour corriger une « erreur de doigt ».
- Les objets `Polygon` sont reconstruits à chaque changement, uniquement avec une nouvelle couleur : les listes de points `contour` sont partagées et jamais recopiées.

### 5.2 `PositionController extends ChangeNotifier`

- `demarrer()` / `arreter()` : **uniquement sur le bouton « Me localiser »**, jamais au lancement (voir §7.6).
- Expose `position` (`LatLng?`), `precision` et `erreur` (refusé, indisponible, délai dépassé).
- S'arrête quand l'app passe en arrière-plan (`AppLifecycleListener`) et reprend au retour si elle était active.

### 5.3 Câblage

Les deux contrôleurs sont créés dans `main()` puis passés aux widgets par leur constructeur, ou par un petit `InheritedWidget`. Chaque widget se met à jour avec un `ListenableBuilder` : la barre d'avancement n'écoute que le `TourneeController`, le point bleu que le `PositionController`.

---

## 6. La carte (flutter_map 8)

```dart
FlutterMap(
  options: MapOptions(
    initialCenter: centreDuVillage, initialZoom: 16,
    minZoom: 13, maxZoom: 19,
    backgroundColor: Color(0xFFEDEDED),        // fond neutre hors-ligne
    interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'fr.amicale.tournee_calendriers',
      keepBuffer: 1, panBuffer: 0,              // limite la mémoire sur iPhone
    ),
    GestureDetector(
      onTap: () => controller.selectionner(hitNotifier.value?.hitValues.firstOrNull),
      child: PolygonLayer<String>(
        hitNotifier: hitNotifier,               // LayerHitNotifier<String>
        polygons: [/* Polygon<String>(points: b.contour, hitValue: b.id, color: …) */],
        simplificationTolerance: 0,             // déjà simplifiés par le script
      ),
    ),
    CouchePosition(),                           // CircleLayer : point bleu + cercle de précision
    RichAttributionWidget(attributions: [
      TextSourceAttribution('© les contributeurs OpenStreetMap'),
      TextSourceAttribution('Cadastre – DGFiP / Etalab, Licence Ouverte'),
    ]),
  ],
)
```

- Détection du toucher : un `GestureDetector` entoure le `PolygonLayer`. On lit ensuite `hitNotifier.value?.hitValues`, qui contient les `hitValue` des polygones touchés, du dessus vers le dessous.
- Le remplissage par défaut sur le web (`evenOdd`) convient. Ne pas utiliser `pathCombine`, qui provoque des défauts d'affichage sur le web.
- Bordures fines (1 px), sans arrondis coûteux.
- Gros boutons : le panneau du bas fait au minimum 56 px de haut par bouton, et la carte ne se recentre pas toute seule pendant qu'on vise une maison.
- L'attribution OSM est **obligatoire**. La politique d'OSM interdit le pré-téléchargement massif de tuiles : on garde seulement en cache les tuiles déjà vues (§7.2), avec une limite de taille.

---

## 7. Pièges de Flutter Web sur iOS Safari

### 7.1 Le service worker Flutter ne fait plus de hors-ligne ⚠️ (vérifié dans le SDK 3.47.9)

L'état actuel, vérifié dans `flutter_tools` :
- L'option `--pwa-strategy` est **masquée et dépréciée**. L'utiliser affiche : *« deprecated and will be removed in a future Flutter release »* (issue flutter/flutter#156910).
- Le fichier `flutter_service_worker.js` généré au build ne fait plus que **31 lignes** : à l'activation, il **se désinscrit lui-même**, puis recharge la page. Il ne met **rien** en cache. Il sert uniquement à nettoyer les anciens service workers Flutter.
- Le `flutter_bootstrap.js` généré par défaut **enregistre quand même** ce service worker. Les anciens tutoriels qui disent « Flutter web est une PWA hors-ligne par défaut » sont donc **faux** aujourd'hui.

**Conséquence : on écrit notre propre service worker** (F7). Un seul service worker peut contrôler une même portée (`scope`). Si celui de Flutter était enregistré, il remplacerait le nôtre, puis se désinscrirait, et le hors-ligne disparaîtrait sans prévenir.

Mise en œuvre :

1. **`web/flutter_bootstrap.js` personnalisé.** Il n'a pas de `serviceWorkerSettings`, donc Flutter n'enregistre pas son propre service worker. C'est nous qui enregistrons le nôtre :
   ```js
   {{flutter_js}}
   {{flutter_build_config}}
   _flutter.loader.load();
   if ('serviceWorker' in navigator) {
     window.addEventListener('load', () => navigator.serviceWorker.register('sw.js'));
   }
   ```
2. **`tool/sw_modele.js`** + **`tool/generer_sw.dart`**. Après `flutter build web`, le script :
   - liste les fichiers de `build/web` ;
   - calcule une empreinte (hash) globale ;
   - écrit `build/web/sw.js` avec la liste des fichiers à pré-cacher et un nom de cache versionné.

   Comme le contenu de `sw.js` change à chaque version, iOS détecte la mise à jour.
3. **Stratégie de cache de `sw.js` :**
   - `install` : pré-cache **tout** l'app shell. Cela comprend `index.html`, `flutter_bootstrap.js`, `flutter.js`, `main.dart.js`, `canvaskit/canvaskit.{js,wasm}`, `assets/**` (dont `batiments.json` et les polices), `manifest.json` et les icônes.
   - App shell : **cache d'abord** (démarrage instantané, même avec une 4G faible).
   - `index.html` : **cache d'abord, avec rafraîchissement en arrière-plan.** Une nouvelle version s'applique donc au lancement suivant.
   - Tuiles OSM : cache séparé, rempli seulement avec les tuiles **vues**. Taille plafonnée (par ex. 1 500 tuiles), les plus anciennes sont supprimées.
   - `activate` : supprime les anciens caches de l'app, puis `clients.claim()`.
4. **Le service worker ne touche jamais à IndexedDB.** Une mise à jour de l'app n'efface donc pas les statuts.

**Mis en œuvre à l'étape 4 (11/11/2026) :**
- Pré-cache : 27 fichiers, 11,7 Mo avant compression, dont 7,3 Mo pour `canvaskit.wasm`.
- `flutter_bootstrap.js` force `canvasKitVariant: 'full'` : c'est la seule variante que Safari utilise. Les autres (`chromium`, `webparagraph`, `skwasm`, `wimp`) sont exclues du cache, et Chrome se comporte ainsi comme l'iPhone.
- L'installation utilise `cache: 'no-cache'` : chaque fichier est revalidé, sans retéléchargement s'il est déjà en cache HTTP.
- Vérifié sur le PC, serveur arrêté : l'app démarre, relit et enregistre les statuts, et affiche les tuiles déjà vues. Le passage à une nouvelle version supprime l'ancien cache et garde les tuiles.

### 7.2 Ressources chargées depuis les serveurs Google ⚠️

Par défaut, une app Flutter web télécharge :
- **CanvasKit** (le moteur de rendu, environ 1,5 Mo de wasm) depuis `www.gstatic.com` ;
- les **polices de secours** (Roboto, emojis, caractères rares) depuis `fonts.gstatic.com`.

Hors-ligne, au premier lancement sans réseau, l'app peut ne rien afficher ou afficher du texte vide.

> Constaté le 11/11/2026 sur le build de production de l'étape 3 : l'app charge `www.gstatic.com/flutter-canvaskit/…` et `fonts.gstatic.com/s/roboto/…`.

Parades :
- Construire avec **`--no-web-resources-cdn`** : CanvasKit est alors servi par notre propre site, donc pré-caché par `sw.js`.
- **Embarquer une police** (par ex. Roboto ou Inter, dans `assets/fonts/`), déclarée dans `pubspec.yaml` et utilisée comme `fontFamily` du thème.
- **Pas d'emojis** dans l'interface : ils déclenchent le téléchargement de Noto Color Emoji.
- Les icônes Material sont embarquées automatiquement. On garde l'élagage des icônes (« tree-shaking »), actif par défaut.

### 7.3 Pas de WebAssembly (skwasm) sur iOS

Sur iOS, tous les navigateurs utilisent WebKit, et Flutter désactive par défaut sa version WebAssembly pour WebKit. Il retombe automatiquement sur JavaScript + CanvasKit (voir [docs.flutter.dev/to/wasm](https://docs.flutter.dev/platform-integration/web/wasm)).
→ **On construit en JavaScript (par défaut, sans `--wasm`).** Le build est plus simple, et c'est de toute façon ce que l'iPhone exécutera.

### 7.4 Poids du premier chargement

`main.dart.js` (environ 2 Mo) + CanvasKit (environ 1,5 Mo) + bâtiments et polices font 4 à 5 Mo au premier lancement.
- **Installer l'app en Wi-Fi**, puis l'ouvrir une fois depuis l'icône pour remplir le cache.
- Ajouter un écran de chargement HTML/CSS dans `index.html`, sinon l'écran reste blanc plusieurs secondes.

### 7.5 Stockage : Safari et l'icône d'accueil sont deux mondes séparés ⚠️

- L'app ajoutée à l'écran d'accueil a **son propre stockage** (IndexedDB, cache du service worker), **séparé de l'onglet Safari**. Des statuts saisis dans Safari *avant* l'installation **n'apparaîtront pas** dans l'app installée.
  → Installer l'app sur l'écran d'accueil **avant** la tournée et n'utiliser que l'icône. L'app peut détecter le mode `display-mode: standalone` et afficher un avertissement si elle est ouverte dans un onglet.
- Dans un onglet Safari, iOS peut effacer les données d'un site après 7 jours sans visite. Une app installée sur l'écran d'accueil est protégée de cette règle, mais **la suppression de l'icône efface tout**.
- Au premier lancement, appeler **`navigator.storage.persist()`** (via `package:web`) pour demander un stockage persistant, et afficher le résultat dans le menu.
- **L'export régulier (F8) reste la vraie sauvegarde.** Le menu peut afficher « Dernier export : il y a 3 jours ».

### 7.6 Géolocalisation

- Elle n'existe qu'en **HTTPS**. `http://192.168.x.x` depuis le PC ne marchera pas sur l'iPhone ; GitHub Pages fournit HTTPS.
- Dans une app installée sur l'écran d'accueil, **iOS peut redemander l'autorisation à chaque lancement, ou chaque jour.** C'est rapporté par plusieurs développeurs, mais Apple n'a rien documenté officiellement.
  → On ne demande la position **que sur le bouton « Me localiser »**, jamais au démarrage.
- `navigator.permissions` n'est pas fiable sur iOS : un refus peut apparaître comme « à demander ». On ne s'appuie donc pas sur `Geolocator.checkPermission()`. On lance le flux de position et on gère l'erreur proprement.
- iOS met en pause une app web en arrière-plan : le flux GPS s'arrête. On le relance au retour au premier plan (`AppLifecycleListener`).

### 7.7 Export / import de fichiers

- L'iPhone n'a pas de système de fichiers accessible directement. L'export passe par `share_plus`, qui ouvre la feuille de partage iOS avec un fichier : « Enregistrer dans Fichiers » ou iCloud Drive.
- La feuille de partage **doit être ouverte en réponse directe à un toucher**. S'il y a une longue attente (`await`) entre le toucher et l'ouverture, Safari peut la bloquer. → Préparer le fichier JSON **avant** l'appui, ou en mémoire de façon synchrone.
- Si le partage échoue, prévoir un téléchargement classique. Dans une app installée sur l'écran d'accueil, ce téléchargement s'ouvre parfois dans un aperçu : **à tester sur l'iPhone.**
- L'import via `file_picker` (champ fichier HTML) fonctionne avec Fichiers et iCloud Drive.

### 7.8 Mémoire et rendu

- CanvasKit utilise WebGL. Sur un iPhone ancien, trop de tuiles ou de grosses images peuvent faire **recharger la page** (perte du contexte WebGL).
  → `keepBuffer` faible, `maxZoom` à 19, polygones simplifiés, pas d'images lourdes.
- La couleur d'une maison change instantanément, même si 1 000 polygones sont redessinés : c'est négligeable à cette échelle.

### 7.9 Écran de l'iPhone (encoche, barre d'accueil)

- Dans `index.html`, garder `apple-mobile-web-app-status-bar-style` à `default` ou `black` (pas `black-translucent`), pour que l'app ne passe pas sous l'heure et la batterie.
- **À vérifier sur l'appareil** : la marge du bas (barre d'accueil) peut valoir 0 sur le web. Ajouter une marge fixe sous le panneau de statut si les boutons sont trop bas.
- Renseigner le nom affiché sous l'icône (`apple-mobile-web-app-title`) et l'icône `apple-touch-icon`. iOS lit celles-ci plutôt que celles du `manifest.json`.

### 7.10 Développer sans Mac

- L'inspecteur web de Safari pour iPhone nécessite un Mac. **Sans Mac, on ne voit pas les erreurs JavaScript de l'iPhone.**
  → Ajouter dans l'app une **page « Diagnostic »** cachée dans le menu : version de l'app, version des bâtiments, état du service worker, stockage persistant oui/non, nombre de statuts, 50 dernières erreurs capturées (`FlutterError.onError`, `PlatformDispatcher.instance.onError`).
- Au quotidien, on développe avec `flutter run -d chrome` sur le PC. **Le hors-ligne ne se teste qu'en build de release** (`flutter build web` puis serveur local), car le service worker n'est pas actif en mode debug.
- Le test final se fait toujours sur **l'iPhone réel**, avec l'app installée sur l'écran d'accueil et le mode Avion activé.

---

## 8. Build et déploiement

En pratique, c'est **`.github/workflows/deployer.yml`** qui le fait à chaque `git push` sur `main` : analyse, tests, build, génération de `sw.js`, puis publication sur https://celestindeal.github.io/tournee-calendriers/. Rien n'est publié si un test échoue. Les commandes équivalentes :

```bash
flutter build web --release --no-web-resources-cdn --base-href /tournee-calendriers/
```
```bash
dart run tool/generer_sw.dart
```

Pour tester la version de production sur le PC (http://localhost:8080), sans `--base-href`. Le hors-ligne s'y teste en arrêtant le serveur puis en rechargeant :

```bash
flutter build web --release --no-web-resources-cdn
```
```bash
dart run tool/generer_sw.dart
```
```bash
dart run tool/servir_web.dart
```

Le mode debug (`flutter run -d web-server`) reste bloqué au démarrage sans l'extension Chrome « Dart Debug » : utiliser `flutter run -d chrome`, ou la version de production ci-dessus.

- `--base-href /tournee-calendriers/` : GitHub Pages sert le site sous `https://celestindeal.github.io/tournee-calendriers/`. Dans `manifest.json`, `start_url` et `scope` doivent être relatifs (`"./"`).

---

## 9. Ordre de réalisation proposé

1. ✅ `tool/preparer_donnees.dart` + `assets/data/batiments.json` (Saint-Héand, 42234).
2. ✅ Modèles + `TourneeRepository` + tests unitaires.
3. ✅ Carte + polygones + panneau de statut + couleurs + barre d'avancement (F1–F5).
4. ✅ Police embarquée, `flutter_bootstrap.js` personnalisé, `sw.js` + script, puis déploiement sur GitHub Pages et **premier test sur l'iPhone** (F7). Test réussi le 11/11/2026 : installation depuis Safari, statut changé, puis réouverture et changement de statut en mode Avion.
5. ✅ GPS (F6), export/import (F8), page Diagnostic. Avant chaque import, une copie de la tournée est gardée dans IndexedDB (meta `sauvegardeAvantImport`), et le menu permet d'« Annuler le dernier import ». Le navigateur interdit d'ouvrir la feuille de partage sans toucher l'écran : l'« export automatique » du §4.5 n'est donc pas possible sur le web. La version de l'app (identifiant du commit) est passée au build par `--dart-define=VERSION_APP`.
6. Filtres, annulation, nouvelle campagne (F9–F11).

---

## 10. Points ouverts

| Sujet | Décision à prendre / à vérifier |
| --- | --- |
| Seuil de surface, types gardés | 20 m², types 01 et 03 : à ajuster après avoir vu la carte (relancer le script avec `--surface-min`, `--types`) |
| Marges de l'iPhone, export dans une app installée | À tester sur l'appareil |

## Sources

- Code de `flutter_tools` 3.47.9 (`lib/src/web/file_generators/js/flutter_service_worker.js`, `lib/src/commands/build_web.dart`, `lib/src/build_system/targets/web.dart`) ; issue [flutter/flutter#156910](https://github.com/flutter/flutter/issues/156910)
- [Flutter – Support for WebAssembly](https://docs.flutter.dev/platform-integration/web/wasm)
- [flutter_map – Polygon Layer](https://docs.fleaflet.dev/layers/polygon-layer) et [Layer Interactivity](https://docs.fleaflet.dev/layers/layer-interactivity)
- Rapports sur la géolocalisation des apps web installées sur iOS : [Apple Developer Forums #775716](https://developer.apple.com/forums/thread/775716), [#694999](https://developer.apple.com/forums/thread/694999), [WebKit bug 255936](https://auto-bugs.webkit.org/show_bug.cgi?id=255936)
- pub.dev (versions relevées le 11/11/2026)
