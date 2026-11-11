// Prépare assets/data/batiments.json à partir du cadastre Etalab et de la
// Base Adresse Nationale (BAN). À lancer une fois, avant la mise en ligne :
//
//   dart run tool/preparer_donnees.dart
//
// Options :
//   --insee 42234            code INSEE de la commune
//   --surface-min 20         surface minimale gardée, en m²
//   --distance-max 60        distance maximale bâtiment → adresse, en mètres
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
const _urlBan = 'https://adresse.data.gouv.fr/data/ban/adresses/latest/csv/adresses-{dep}.csv.gz';

/// Tolérance de simplification des contours, en mètres.
const _toleranceSimplification = 0.3;

Future<void> main(List<String> args) async {
  String option(String nom, String defaut) {
    final i = args.indexOf('--$nom');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : defaut;
  }

  final insee = option('insee', '42234');
  final surfaceMin = double.parse(option('surface-min', '20'));
  final distanceMax = double.parse(option('distance-max', '60'));
  final typesGardes = option('types', '01,03').split(',').toSet();
  final retelecharger = args.contains('--retelecharger');
  final dep = insee.startsWith('97') ? insee.substring(0, 3) : insee.substring(0, 2);

  final racine = File.fromUri(Platform.script).parent.parent;
  final dossierBrut = Directory('${racine.path}/donnees_brutes')..createSync(recursive: true);
  final sortie = File('${racine.path}/assets/data/batiments.json');

  // 1. Téléchargement des fichiers bruts (si absents).
  final fCadastre = File('${dossierBrut.path}/cadastre-$insee-batiments.json.gz');
  final fBan = File('${dossierBrut.path}/adresses-$dep.csv.gz');
  final srcCadastre = await _obtenir(
    _urlCadastre.replaceAll('{dep}', dep).replaceAll('{insee}', insee),
    fCadastre,
    retelecharger,
  );
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
        for (final requis in ['code_insee', 'numero', 'rep', 'nom_voie', 'lon', 'lat', 'type_position', 'nom_ld', 'nom_commune']) {
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
      adresses.add(_Adresse(
        pt.x,
        pt.y,
        _libelle(c[col['numero']!], c[col['rep']!], c[col['nom_voie']!], c[col['nom_ld']!]),
        c[col['type_position']!],
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

  // 6. Écriture du fichier.
  var minLat = 90.0, minLon = 180.0, maxLat = -90.0, maxLon = -180.0;
  for (final b in gardes) {
    for (final r in b.parties) {
      for (final p in r) {
        minLat = min(minLat, p.y);
        maxLat = max(maxLat, p.y);
        minLon = min(minLon, p.x);
        maxLon = max(maxLon, p.x);
      }
    }
  }
  final listeBatiments = [
    for (final b in gardes)
      {
        'id': b.id,
        if (b.adresse != null) 'a': b.adresse!.libelle,
        's': double.parse(b.surface.toStringAsFixed(1)),
        'c': _coord(b.centre),
        'p': [
          for (final r in b.parties) [for (final p in r) _coord(p)],
        ],
      },
  ];
  final empreinte = _fnv1a(jsonEncode(listeBatiments));
  final millesimeCadastre = srcCadastre['millesime'] ?? 'inconnu';
  final donnees = {
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
    'batiments': listeBatiments,
  };
  sortie.parent.createSync(recursive: true);
  sortie.writeAsStringSync(jsonEncode(donnees));

  // 7. Bilan.
  final avecAdresse = gardes.where((b) => b.adresse != null).length;
  final adressesUtilisees = gardes.map((b) => b.adresse).whereType<_Adresse>().toSet();
  final parAdresse = <_Adresse, int>{};
  for (final b in gardes) {
    if (b.adresse != null) parAdresse[b.adresse!] = (parAdresse[b.adresse!] ?? 0) + 1;
  }
  final tailleKo = sortie.lengthSync() / 1024;
  final tailleGzKo = gzip.encode(sortie.readAsBytesSync()).length / 1024;
  int nbDist(double max) => distances.where((d) => d <= max).length;

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
  print('Distance à l\'adresse la plus proche :');
  for (final d in [20.0, 40.0, 60.0, 100.0]) {
    print('  ≤ ${d.toStringAsFixed(0).padLeft(3)} m : ${nbDist(d)} (${(100 * nbDist(d) / gardes.length).toStringAsFixed(0)} %)');
  }
  print('Bâtiments avec adresse  $avecAdresse / ${gardes.length} (seuil $distanceMax m)');
  print('Adresses BAN utilisées  ${adressesUtilisees.length} / ${adresses.length}');
  print('Max bâtiments / adresse ${parAdresse.values.fold(0, max)}');
  print('');
  print('Fichier ............... ${sortie.path}');
  print('Taille ................ ${tailleKo.toStringAsFixed(0)} Ko (${tailleGzKo.toStringAsFixed(0)} Ko compressé)');
  print('Version ............... ${donnees['version']}');
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
  _Adresse(this.x, this.y, this.libelle, this.typePosition);
  final double x, y;
  final String libelle, typePosition;
}

class _Batiment {
  _Batiment({required this.geohash, required this.surface, required this.centre, required this.adresse, required this.parties});
  final String geohash;
  final double surface;
  final Point<double> centre;
  final _Adresse? adresse;
  final List<List<Point<double>>> parties;
  late String id;
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
