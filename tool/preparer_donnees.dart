// Prépare assets/data/parcelles.json à partir du cadastre Etalab (bâtiments
// et parcelles) et de la Base Adresse Nationale (BAN), pour toutes les
// communes de la tournée. À lancer une fois, avant la mise en ligne :
//
//   dart run tool/preparer_donnees.dart
//
// L'unité de suivi est la PARCELLE cadastrale qui contient au moins un
// bâtiment gardé : on touche un bâtiment, toute la parcelle prend la couleur.
// Chaque parcelle garde les anciens identifiants de ses bâtiments (géohash),
// pour reporter les statuts saisis avant le passage aux parcelles.
// Chaque commune est traitée séparément, exactement de la même façon (les
// identifiants d'une commune ne dépendent pas des autres), puis tout est
// réuni dans un seul fichier.
//
// Options :
//   --insee 42234,42010      codes INSEE des communes (par défaut : les 6 de la tournée)
//   --surface-min 20         surface minimale des bâtiments gardés, en m²
//   --distance-max 60        distance maximale bâtiment → adresse (secours), en mètres
//   --types 01,03            types de bâti gardés (01 = dur, 02 = léger, 03 = autre)
//   --retelecharger          retélécharge les fichiers bruts même s'ils existent
//
// N'utilise que la bibliothèque standard de Dart.

// Script en ligne de commande : print est la sortie normale.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _urlCadastre =
    'https://cadastre.data.gouv.fr/data/etalab-cadastre/latest/geojson/communes/{dep}/{insee}/cadastre-{insee}-batiments.json.gz';
const _urlParcelles =
    'https://cadastre.data.gouv.fr/data/etalab-cadastre/latest/geojson/communes/{dep}/{insee}/cadastre-{insee}-parcelles.json.gz';
const _urlBan = 'https://adresse.data.gouv.fr/data/ban/adresses/latest/csv/adresses-{dep}.csv.gz';

/// Tolérance de simplification des contours de bâtiments, en mètres.
const _toleranceSimplification = 0.3;

/// Tolérance de simplification des contours de parcelles, en mètres.
const _toleranceParcelles = 0.5;

/// Communes de la tournée : Saint-Héand, Aveizieux, Saint-Bonnet-les-Oules,
/// La Gimond, Fontanès, La Fouillouse.
const _communesParDefaut = '42234,42010,42206,42100,42096,42097';

Future<void> main(List<String> args) async {
  String option(String nom, String defaut) {
    final i = args.indexOf('--$nom');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : defaut;
  }

  final codes = option('insee', _communesParDefaut).split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
  final surfaceMin = double.parse(option('surface-min', '20'));
  final distanceMax = double.parse(option('distance-max', '60'));
  final typesGardes = option('types', '01,03').split(',').toSet();
  final retelecharger = args.contains('--retelecharger');

  final racine = File.fromUri(Platform.script).parent.parent;
  final dossierBrut = Directory('${racine.path}/donnees_brutes')..createSync(recursive: true);
  final sortie = File('${racine.path}/assets/data/parcelles.json');

  // 1. Chaque commune, traitée séparément.
  final resultats = <Map<String, dynamic>>[];
  for (final insee in codes) {
    print('══════════ Commune $insee ══════════');
    resultats.add(await _traiterCommune(
      insee,
      dossierBrut: dossierBrut,
      surfaceMin: surfaceMin,
      distanceMax: distanceMax,
      typesGardes: typesGardes,
      retelecharger: retelecharger,
    ));
    print('');
  }

  // 2. Réunion : chaque parcelle porte le code INSEE de sa commune (« co »).
  final unites = <Map<String, Object>>[
    for (final r in resultats)
      for (final u in (r['parcelles'] as List).cast<Map<String, Object>>()) {...u, 'co': (r['commune'] as Map)['insee'] as String},
  ];
  final vus = <String>{};
  for (final u in unites) {
    if (!vus.add(u['id']! as String)) _erreur('Identifiant en double entre deux communes : ${u['id']}');
  }
  var minLat = 90.0, minLon = 180.0, maxLat = -90.0, maxLon = -180.0;
  for (final r in resultats) {
    final bbox = r['bbox'] as List;
    minLat = min(minLat, (bbox[0] as List)[0] as double);
    minLon = min(minLon, (bbox[0] as List)[1] as double);
    maxLat = max(maxLat, (bbox[1] as List)[0] as double);
    maxLon = max(maxLon, (bbox[1] as List)[1] as double);
  }
  final millesimes = {for (final r in resultats) r['millesime'] as String}.join('+');
  final donnees = {
    // 3 = plusieurs communes (2 = une seule commune, 1 = suivi par bâtiment).
    'format': 3,
    'version': '$millesimes-${_fnv1a(jsonEncode(unites))}',
    'communes': [
      for (final r in resultats)
        {
          ...(r['commune'] as Map).cast<String, Object?>(),
          'version': r['version'],
          'parcelles': (r['parcelles'] as List).length,
          'bbox': r['bbox'], // emprise de la commune (vue de départ de la carte)
        },
    ],
    'sources': resultats.first['sources'],
    'parametres': resultats.first['parametres'],
    'centre': _coord(Point((minLon + maxLon) / 2, (minLat + maxLat) / 2)),
    'bbox': [
      [minLat, minLon],
      [maxLat, maxLon],
    ],
    'parcelles': unites,
  };
  sortie.parent.createSync(recursive: true);
  sortie.writeAsStringSync(jsonEncode(donnees));
  // Les anciens fichiers ne sont plus utilisés.
  final ancien = File('${racine.path}/assets/data/batiments.json');
  if (ancien.existsSync()) ancien.deleteSync();

  // 3. Bilan.
  print('══════════ Total ══════════');
  for (final c in donnees['communes']! as List) {
    final m = c as Map;
    print('${(m['nom'] as String).padRight(24)} ${m['insee']}  ${m['parcelles'].toString().padLeft(5)} unités  (version ${m['version']})');
  }
  print('Unités suivies ........ ${unites.length}');
  print('Bâtiments ............. ${unites.fold<int>(0, (n, u) => n + (u['b']! as List).length)}');
  print('Fichier ............... ${sortie.path}');
  print('Taille ................ ${(sortie.lengthSync() / 1024).toStringAsFixed(0)} Ko '
      '(${(gzip.encode(sortie.readAsBytesSync()).length / 1024).toStringAsFixed(0)} Ko compressé)');
  print('Version ............... ${donnees['version']}');
}

/// Traite une commune et renvoie ses données (sans rien écrire).
Future<Map<String, dynamic>> _traiterCommune(
  String insee, {
  required Directory dossierBrut,
  required double surfaceMin,
  required double distanceMax,
  required Set<String> typesGardes,
  required bool retelecharger,
}) async {
  final dep = insee.startsWith('97') ? insee.substring(0, 3) : insee.substring(0, 2);

  // 1. Téléchargement des fichiers bruts (si absents).
  final fCadastre = File('${dossierBrut.path}/cadastre-$insee-batiments.json.gz');
  final fParcelles = File('${dossierBrut.path}/cadastre-$insee-parcelles.json.gz');
  final fBan = File('${dossierBrut.path}/adresses-$dep.csv.gz');
  final srcCadastre = await _obtenir(
    _urlCadastre.replaceAll('{dep}', dep).replaceAll('{insee}', insee),
    fCadastre,
    retelecharger,
  );
  await _obtenir(_urlParcelles.replaceAll('{dep}', dep).replaceAll('{insee}', insee), fParcelles, retelecharger);
  final srcBan = await _obtenir(_urlBan.replaceAll('{dep}', dep), fBan, retelecharger);

  // 2. Lecture des bâtiments.
  final geo = jsonDecode(utf8.decode(gzip.decode(fCadastre.readAsBytesSync()))) as Map<String, dynamic>;
  final features = (geo['features'] as List).cast<Map<String, dynamic>>();
  if (features.isEmpty) _erreur('Aucun bâtiment dans le cadastre de $insee.');

  // Projection locale en mètres, centrée sur le premier point du fichier.
  final p0 = _premierPoint(features.first['geometry'] as Map<String, dynamic>);
  final proj = _Projection(p0[1], p0[0]);

  // 3. Lecture des adresses de la commune.
  final adresses = <_Adresse>[];
  String? nomCommune;
  {
    final lignes = fBan.openRead().transform(gzip.decoder).transform(utf8.decoder).transform(const LineSplitter());
    Map<String, int>? col;
    await for (final ligne in lignes) {
      final c = ligne.split(';');
      if (col == null) {
        col = {for (var i = 0; i < c.length; i++) c[i]: i};
        for (final requis in [
          'code_insee', 'numero', 'rep', 'nom_voie', 'lon', 'lat', 'type_position', 'nom_ld', 'nom_commune', //
          'cad_parcelles',
        ]) {
          if (!col.containsKey(requis)) _erreur('Colonne "$requis" absente du fichier BAN.');
        }
        continue;
      }
      if (c[col['code_insee']!] != insee) continue;
      final lon = double.tryParse(c[col['lon']!]);
      final lat = double.tryParse(c[col['lat']!]);
      if (lon == null || lat == null) continue;
      nomCommune ??= c[col['nom_commune']!];
      final pt = proj.versMetres(lat, lon);
      final numero = c[col['numero']!];
      adresses.add(_Adresse(
        pt.x,
        pt.y,
        _libelle(numero, c[col['rep']!], c[col['nom_voie']!], c[col['nom_ld']!]),
        c[col['type_position']!],
        voie: c[col['nom_voie']!],
        numero: int.tryParse(numero) ?? 0,
        // Parcelles cadastrales liées à l'adresse, séparées par « | ».
        parcelles: c[col['cad_parcelles']!].split('|').where((p) => p.isNotEmpty).toList(),
      ));
    }
  }
  if (adresses.isEmpty) _erreur('Aucune adresse BAN pour $insee.');

  // 4. Filtrage, simplification, centre, adresse.
  var rejetesType = 0, rejetesSurface = 0, multiParties = 0, ptsAvant = 0, ptsApres = 0;
  final distances = <double>[];
  final gardes = <_Batiment>[];
  for (final f in features) {
    final props = f['properties'] as Map<String, dynamic>;
    if (!typesGardes.contains('${props['type']}')) {
      rejetesType++;
      continue;
    }
    final g = f['geometry'] as Map<String, dynamic>;
    final polygones = g['type'] == 'Polygon' ? [g['coordinates'] as List] : (g['coordinates'] as List).cast<List>();
    // On ne garde que le contour extérieur de chaque partie (les cours intérieures sont ignorées).
    final parties = <List<Point<double>>>[
      for (final poly in polygones)
        [for (final c in (poly.first as List)) proj.versMetres((c as List)[1] as num, c[0] as num)],
    ];
    final surface = parties.fold<double>(0, (s, r) => s + _surface(r).abs());
    if (surface < surfaceMin) {
      rejetesSurface++;
      continue;
    }
    if (parties.length > 1) multiParties++;

    final simplifiees = <List<Point<double>>>[];
    for (final r in parties) {
      ptsAvant += r.length - 1;
      var s = _simplifier(r, _toleranceSimplification);
      if (s.length < 4) s = r; // un polygone fermé a au moins 3 sommets + le point de fermeture
      ptsApres += s.length - 1;
      simplifiees.add(s);
    }

    final principale = parties.reduce((a, b) => _surface(a).abs() >= _surface(b).abs() ? a : b);
    final centre = _centroide(principale);

    _Adresse? plusProche;
    var dMin = double.infinity;
    for (final a in adresses) {
      final d = (a.x - centre.x) * (a.x - centre.x) + (a.y - centre.y) * (a.y - centre.y);
      if (d < dMin) {
        dMin = d;
        plusProche = a;
      }
    }
    dMin = sqrt(dMin);
    distances.add(dMin);

    final centreGeo = proj.versDegres(centre);
    gardes.add(_Batiment(
      geohash: _geohash(centreGeo.y, centreGeo.x, 9),
      surface: surface,
      centre: centreGeo,
      centreM: centre,
      adresse: dMin <= distanceMax ? plusProche : null,
      parties: [
        for (final r in simplifiees)
          // Le point de fermeture est retiré : flutter_map ferme les polygones tout seul.
          [for (final p in r.sublist(0, r.length - 1)) proj.versDegres(p)],
      ],
    ));
  }

  // 5. Identifiants stables : géohash du centre (≈ 5 m), suffixe en cas de doublon.
  //    Tri par géohash puis surface décroissante : sortie déterministe et
  //    bâtiments voisins côte à côte (meilleur regroupement au dessin).
  gardes.sort((a, b) {
    final c = a.geohash.compareTo(b.geohash);
    return c != 0 ? c : b.surface.compareTo(a.surface);
  });
  final vus = <String, int>{};
  var collisions = 0;
  for (final b in gardes) {
    final n = (vus[b.geohash] ?? 0) + 1;
    vus[b.geohash] = n;
    b.id = n == 1 ? b.geohash : '${b.geohash}-$n';
    if (n > 1) collisions++;
  }

  // 6. Parcelles : chaque bâtiment est rattaché à la parcelle qui contient son centre.
  final geoParcelles = jsonDecode(utf8.decode(gzip.decode(fParcelles.readAsBytesSync()))) as Map<String, dynamic>;
  final parcellesBrutes = <String, _ParcelleBrute>{};
  for (final f in (geoParcelles['features'] as List).cast<Map<String, dynamic>>()) {
    final g = f['geometry'] as Map<String, dynamic>;
    final polygones = g['type'] == 'Polygon' ? [g['coordinates'] as List] : (g['coordinates'] as List).cast<List>();
    final props = f['properties'] as Map<String, dynamic>;
    final id = f['id'] as String;
    parcellesBrutes[id] = _ParcelleBrute(
      id,
      // Contour extérieur seulement (les enclaves sont ignorées).
      [
        for (final poly in polygones)
          [for (final c in (poly.first as List)) proj.versMetres((c as List)[1] as num, c[0] as num)],
      ],
      (props['contenance'] as num?)?.toDouble(),
    );
  }
  final batimentsParParcelle = <String, List<_Batiment>>{};
  final orphelins = <_Batiment>[];
  for (final b in gardes) {
    final p = parcellesBrutes.values.where((p) => p.contient(b.centreM)).firstOrNull;
    if (p == null) {
      orphelins.add(b);
    } else {
      batimentsParParcelle.putIfAbsent(p.id, () => []).add(b);
    }
  }

  // Adresses de chaque parcelle : liées par la BAN (colonne cad_parcelles,
  // peu remplie à Saint-Héand) ou dont le point tombe dans la parcelle.
  final adressesBan = <String, List<_Adresse>>{};
  for (final a in adresses) {
    for (final p in a.parcelles) {
      adressesBan.putIfAbsent(p, () => []).add(a);
    }
  }
  for (final id in batimentsParParcelle.keys) {
    final p = parcellesBrutes[id]!;
    for (final a in adresses) {
      if (p.contient(Point(a.x, a.y))) adressesBan.putIfAbsent(id, () => []).add(a);
    }
  }

  // 7. Écriture du fichier.
  var avecAdresseBan = 0, avecAdresseProche = 0, sansAdresse = 0;
  final unites = <Map<String, Object>>[];
  List<List<double>> versCoords(List<Point<double>> contourDegres) => [for (final p in contourDegres) _coord(p)];
  for (final id in batimentsParParcelle.keys.toList()..sort()) {
    final brute = parcellesBrutes[id]!;
    final bats = batimentsParParcelle[id]!..sort((a, b) => b.surface.compareTo(a.surface));
    final liees = adressesBan[id] ?? const <_Adresse>[];
    final String? adresse;
    if (liees.isNotEmpty) {
      adresse = _libelleParcelle(liees);
      avecAdresseBan++;
    } else {
      // Secours : l'adresse la plus proche du bâtiment principal (≤ distance-max).
      adresse = bats.map((b) => b.adresse?.libelle).whereType<String>().firstOrNull;
      adresse == null ? sansAdresse++ : avecAdresseProche++;
    }
    unites.add({
      'id': id,
      'a': ?adresse,
      's': (brute.contenance ?? brute.surface).roundToDouble(),
      'c': _coord(bats.first.centre),
      'p': [
        for (final r in brute.contours)
          // Simplifié, puis sans le point de fermeture (flutter_map ferme seul).
          versCoords([for (final p in _simplifierFerme(r, _toleranceParcelles)) proj.versDegres(p)]),
      ],
      'b': [
        for (final b in bats)
          for (final r in b.parties) versCoords(r),
      ],
      'anciens': [for (final b in bats) b.id],
    });
  }
  // Bâtiments hors de toute parcelle (domaine public…) : suivis seuls.
  for (final b in orphelins) {
    unites.add({
      'id': 'bat-${b.id}',
      'a': ?b.adresse?.libelle,
      's': b.surface.roundToDouble(),
      'c': _coord(b.centre),
      'p': [for (final r in b.parties) versCoords(r)],
      'b': [for (final r in b.parties) versCoords(r)],
      'anciens': [b.id],
    });
    b.adresse == null ? sansAdresse++ : avecAdresseProche++;
  }

  var minLat = 90.0, minLon = 180.0, maxLat = -90.0, maxLon = -180.0;
  for (final u in unites) {
    for (final contour in u['p']! as List) {
      for (final c in contour as List<List<double>>) {
        minLat = min(minLat, c[0]);
        maxLat = max(maxLat, c[0]);
        minLon = min(minLon, c[1]);
        maxLon = max(maxLon, c[1]);
      }
    }
  }
  final empreinte = _fnv1a(jsonEncode(unites));
  final millesimeCadastre = srcCadastre['millesime'] ?? 'inconnu';
  final donnees = {
    'format': 2, // 2 = suivi par parcelle (1 = par bâtiment, avant le 11/11/2026)
    'version': '$millesimeCadastre-$empreinte',
    'commune': {'insee': insee, 'nom': nomCommune},
    'sources': {
      'cadastre': 'Cadastre DGFiP / Etalab, millésime $millesimeCadastre, Licence Ouverte 2.0',
      'adresses': 'Base Adresse Nationale, version du ${srcBan['millesime'] ?? 'inconnue'}, Licence Ouverte 2.0',
    },
    'parametres': {
      'types': typesGardes.toList()..sort(),
      'surfaceMinM2': surfaceMin,
      'distanceAdresseMaxM': distanceMax,
    },
    'centre': _coord(Point((minLon + maxLon) / 2, (minLat + maxLat) / 2)),
    'bbox': [
      [_arrondi(minLat), _arrondi(minLon)],
      [_arrondi(maxLat), _arrondi(maxLon)],
    ],
    'parcelles': unites,
    'millesime': millesimeCadastre,
  };

  // 8. Bilan de la commune.
  int nbDist(double max) => distances.where((d) => d <= max).length;
  final repartition = <int, int>{};
  for (final l in batimentsParParcelle.values) {
    repartition[min(l.length, 5)] = (repartition[min(l.length, 5)] ?? 0) + 1;
  }

  print('Commune ............... $nomCommune ($insee)');
  print('Cadastre .............. millésime $millesimeCadastre');
  print('BAN ................... ${srcBan['millesime']} – ${adresses.length} adresses');
  print('');
  print('Bâtiments lus ......... ${features.length}');
  print('  rejetés (type) ...... $rejetesType  (types gardés : ${typesGardes.join(', ')})');
  print('  rejetés (< $surfaceMin m²) .. $rejetesSurface');
  print('  gardés .............. ${gardes.length}  (dont $multiParties en plusieurs parties)');
  print('Points des contours ... $ptsAvant → $ptsApres après simplification');
  print('Collisions d\'id ....... $collisions (résolues par suffixe)');
  print('');
  print('Distance bâtiment → adresse la plus proche :');
  for (final d in [20.0, 40.0, 60.0, 100.0]) {
    print('  ≤ ${d.toStringAsFixed(0).padLeft(3)} m : ${nbDist(d)} (${(100 * nbDist(d) / gardes.length).toStringAsFixed(0)} %)');
  }
  print('');
  print('Parcelles cadastrales . ${parcellesBrutes.length}');
  print('Unités suivies ........ ${unites.length}  (${batimentsParParcelle.length} parcelles + ${orphelins.length} bâtiments hors parcelle)');
  print('Bâtiments par parcelle  ${(repartition.keys.toList()..sort()).map((k) => '$k${k == 5 ? '+' : ''}: ${repartition[k]}').join('   ')}');
  print('Adresse ............... $avecAdresseBan dans la parcelle (ou liée par la BAN), '
      '$avecAdresseProche la plus proche, $sansAdresse sans');
  print('Parcelles à 2 adresses+ ${unites.where((u) => (u['a'] as String?)?.contains(' / ') ?? false).length}');
  print('Anciens ids reportés .. ${unites.fold<int>(0, (n, u) => n + (u['anciens']! as List).length)} / ${gardes.length}');
  print('Version de la commune . ${donnees['version']}');
  return donnees;
}

// ---------------------------------------------------------------------------
// Téléchargement

/// Télécharge [url] dans [dest] si besoin. Renvoie les infos de source
/// (millésime), mémorisées dans un fichier « .source.json » à côté.
Future<Map<String, String?>> _obtenir(String url, File dest, bool forcer) async {
  final fSource = File('${dest.path}.source.json');
  if (!forcer && dest.existsSync() && fSource.existsSync()) {
    return (jsonDecode(fSource.readAsStringSync()) as Map).cast<String, String?>();
  }
  stdout.writeln('Téléchargement de $url …');
  final client = HttpClient()
    ..autoUncompress = false
    ..userAgent = 'tournee-calendriers/preparer_donnees';
  try {
    final rep = await (await client.getUrl(Uri.parse(url))).close();
    if (rep.statusCode != 200) _erreur('HTTP ${rep.statusCode} pour $url');
    await rep.pipe(dest.openWrite());
    // Cadastre : la date du millésime est dans l'URL de redirection (…/etalab-cadastre/2026-09-01/…).
    // BAN : on prend la date de dernière modification du fichier.
    final redirection = rep.redirects.isEmpty ? '' : rep.redirects.last.location.toString();
    final dateUrl = RegExp(r'/(\d{4}-\d{2}-\d{2})/').firstMatch(redirection)?.group(1);
    final lastModified = rep.headers.value(HttpHeaders.lastModifiedHeader);
    final dateModif = lastModified == null ? null : HttpDate.parse(lastModified).toIso8601String().substring(0, 10);
    final source = {
      'url': url,
      'millesime': dateUrl ?? dateModif,
      'telechargeLe': DateTime.now().toIso8601String(),
    };
    fSource.writeAsStringSync(jsonEncode(source));
    return source;
  } finally {
    client.close();
  }
}

// ---------------------------------------------------------------------------
// Géométrie

class _Projection {
  _Projection(num lat0, num lon0)
      : lat0 = lat0.toDouble(),
        lon0 = lon0.toDouble(),
        kx = 111320 * cos(lat0 * pi / 180),
        ky = 110574;
  final double lat0, lon0, kx, ky;

  Point<double> versMetres(num lat, num lon) => Point((lon - lon0) * kx, (lat - lat0) * ky);

  /// Renvoie un point (x = longitude, y = latitude).
  Point<double> versDegres(Point<double> p) => Point(lon0 + p.x / kx, lat0 + p.y / ky);
}

List<num> _premierPoint(Map<String, dynamic> g) {
  dynamic c = g['coordinates'];
  while (c is List && c.first is List) {
    c = c.first;
  }
  return (c as List).cast<num>();
}

/// Surface signée (formule du lacet), en m².
double _surface(List<Point<double>> r) {
  var s = 0.0;
  for (var i = 0; i < r.length - 1; i++) {
    s += r[i].x * r[i + 1].y - r[i + 1].x * r[i].y;
  }
  return s / 2;
}

Point<double> _centroide(List<Point<double>> r) {
  final a = _surface(r);
  if (a.abs() < 1e-9) {
    final n = r.length - 1;
    return Point(r.take(n).fold(0.0, (s, p) => s + p.x) / n, r.take(n).fold(0.0, (s, p) => s + p.y) / n);
  }
  var cx = 0.0, cy = 0.0;
  for (var i = 0; i < r.length - 1; i++) {
    final f = r[i].x * r[i + 1].y - r[i + 1].x * r[i].y;
    cx += (r[i].x + r[i + 1].x) * f;
    cy += (r[i].y + r[i + 1].y) * f;
  }
  return Point(cx / (6 * a), cy / (6 * a));
}

/// Douglas-Peucker : retire les points qui s'écartent de moins de [tol] mètres.
List<Point<double>> _simplifier(List<Point<double>> pts, double tol) {
  if (pts.length <= 3) return pts;
  final garder = List<bool>.filled(pts.length, false);
  garder[0] = garder[pts.length - 1] = true;
  final pile = <(int, int)>[(0, pts.length - 1)];
  while (pile.isNotEmpty) {
    final (debut, fin) = pile.removeLast();
    var dMax = 0.0;
    var iMax = -1;
    for (var i = debut + 1; i < fin; i++) {
      final d = _distanceSegment(pts[i], pts[debut], pts[fin]);
      if (d > dMax) {
        dMax = d;
        iMax = i;
      }
    }
    if (iMax >= 0 && dMax > tol) {
      garder[iMax] = true;
      pile
        ..add((debut, iMax))
        ..add((iMax, fin));
    }
  }
  return [for (var i = 0; i < pts.length; i++) if (garder[i]) pts[i]];
}

double _distanceSegment(Point<double> p, Point<double> a, Point<double> b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final l2 = dx * dx + dy * dy;
  if (l2 == 0) return p.distanceTo(a); // contour fermé : début == fin
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / l2).clamp(0.0, 1.0);
  return p.distanceTo(Point(a.x + t * dx, a.y + t * dy));
}

String _geohash(double lat, double lon, int precision) {
  const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  var latMin = -90.0, latMax = 90.0, lonMin = -180.0, lonMax = 180.0;
  final sb = StringBuffer();
  var bit = 0, ch = 0;
  var pair = true;
  while (sb.length < precision) {
    if (pair) {
      final mid = (lonMin + lonMax) / 2;
      if (lon >= mid) {
        ch = (ch << 1) | 1;
        lonMin = mid;
      } else {
        ch <<= 1;
        lonMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch <<= 1;
        latMax = mid;
      }
    }
    pair = !pair;
    if (++bit == 5) {
      sb.write(base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return sb.toString();
}

// ---------------------------------------------------------------------------
// Divers

class _Adresse {
  _Adresse(this.x, this.y, this.libelle, this.typePosition,
      {required this.voie, required this.numero, required this.parcelles});
  final double x, y;
  final String libelle, typePosition, voie;
  final int numero;

  /// Identifiants des parcelles cadastrales liées (colonne cad_parcelles de la BAN).
  final List<String> parcelles;
}

class _Batiment {
  _Batiment({
    required this.geohash,
    required this.surface,
    required this.centre,
    required this.centreM,
    required this.adresse,
    required this.parties,
  });
  final String geohash;
  final double surface;

  /// Centre en degrés (x = longitude, y = latitude) et en mètres (projection locale).
  final Point<double> centre, centreM;
  final _Adresse? adresse;

  /// Contours en degrés, sans point de fermeture.
  final List<List<Point<double>>> parties;
  late String id;
}

/// Une parcelle du cadastre, en mètres (projection locale).
class _ParcelleBrute {
  _ParcelleBrute(this.id, this.contours, this.contenance) {
    for (final r in contours) {
      for (final p in r) {
        _xMin = min(_xMin, p.x);
        _xMax = max(_xMax, p.x);
        _yMin = min(_yMin, p.y);
        _yMax = max(_yMax, p.y);
      }
    }
  }

  final String id;
  final List<List<Point<double>>> contours;

  /// Surface officielle en m² (« contenance » du cadastre).
  final double? contenance;
  double _xMin = double.infinity, _xMax = -double.infinity, _yMin = double.infinity, _yMax = -double.infinity;

  double get surface => contours.fold(0, (s, r) => s + _surface(r).abs());

  bool contient(Point<double> p) {
    if (p.x < _xMin || p.x > _xMax || p.y < _yMin || p.y > _yMax) return false;
    for (final r in contours) {
      var dedans = false;
      for (var i = 0, j = r.length - 1; i < r.length; j = i++) {
        if ((r[i].y > p.y) != (r[j].y > p.y) &&
            p.x < (r[j].x - r[i].x) * (p.y - r[i].y) / (r[j].y - r[i].y) + r[i].x) {
          dedans = !dedans;
        }
      }
      if (dedans) return true;
    }
    return false;
  }
}

/// Simplifie un contour fermé et retire le point de fermeture.
List<Point<double>> _simplifierFerme(List<Point<double>> r, double tol) {
  var s = _simplifier(r, tol);
  if (s.length < 4) s = r;
  return s.first == s.last ? s.sublist(0, s.length - 1) : s;
}

/// « 12 Rue Apollo », « 12 Rue Apollo / 14 Rue Apollo », « … (+2) » :
/// adresses d'une parcelle, triées par voie puis numéro.
String _libelleParcelle(List<_Adresse> adresses) {
  final triees = [...adresses]..sort((a, b) {
      final c = a.voie.compareTo(b.voie);
      return c != 0 ? c : a.numero.compareTo(b.numero);
    });
  final libelles = triees.map((a) => a.libelle).toSet().toList();
  final debut = libelles.take(2).join(' / ');
  return libelles.length > 2 ? '$debut (+${libelles.length - 2})' : debut;
}

/// « 12 bis Rue Apollo » ; ajoute le lieu-dit s'il apporte une info.
String _libelle(String numero, String rep, String voie, String lieuDit) {
  final num = numero == '99999' || numero.isEmpty ? '' : '$numero${rep.isEmpty ? '' : ' $rep'} ';
  final ld = lieuDit.isNotEmpty && !voie.toLowerCase().contains(lieuDit.toLowerCase()) ? ', $lieuDit' : '';
  return '$num$voie$ld';
}

/// [lat, lon] arrondis à 6 décimales (≈ 0,1 m).
List<double> _coord(Point<double> p) => [_arrondi(p.y), _arrondi(p.x)];
double _arrondi(double v) => double.parse(v.toStringAsFixed(6));

/// Empreinte FNV-1a 32 bits, en hexadécimal.
String _fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h ^= b;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

Never _erreur(String message) {
  stderr.writeln('Erreur : $message');
  exit(1);
}
