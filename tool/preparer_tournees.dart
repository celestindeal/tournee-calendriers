// Prépare assets/data/tournees.json à partir d'un export KML de Google My
// Maps (⋮ → « Exporter au format KML/KMZ » → « Exporter au format .KML »).
//
//   dart run tool/preparer_tournees.dart chemin/vers/carte.kml [autre.kml …]
//
// Chaque forme (polygone ou ligne fermée) dont le nom contient un numéro
// (« Tournée n°7 », « T7 », « 7 ») devient la tournée de ce numéro. Plusieurs
// formes du même numéro forment une seule tournée. Les formes sans numéro et
// les points (repères) sont ignorés.
//
// N'utilise que la bibliothèque standard de Dart.

// Script en ligne de commande : print est la sortie normale.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

const _sortie = 'assets/data/tournees.json';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Usage : dart run tool/preparer_tournees.dart carte.kml [autre.kml …]');
    exitCode = 64;
    return;
  }
  final tournees = <int, Map<String, Object>>{};
  for (final chemin in arguments) {
    for (final forme in lireKml(File(chemin).readAsStringSync())) {
      final t = tournees.putIfAbsent(
        forme.numero,
        () => {'numero': forme.numero, 'nom': 'Tournée n°${forme.numero}', 'contours': <Object>[]},
      );
      (t['contours'] as List).add([
        for (final (lat, lon) in forme.points) [_arrondi(lat), _arrondi(lon)],
      ]);
      print('${forme.nom} → tournée ${forme.numero} (${forme.points.length} points)');
    }
  }
  final liste = tournees.values.toList()..sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));
  File(_sortie).writeAsStringSync(
    '${const JsonEncoder.withIndent(' ').convert({'format': 1, 'source': 'Google My Maps (export KML)', 'tournees': liste})}\n',
  );
  print('$_sortie : ${liste.length} tournée(s).');
}

double _arrondi(double v) => (v * 1e6).roundToDouble() / 1e6;

/// Une forme nommée d'un fichier KML (contour en latitude, longitude).
typedef FormeKml = ({String nom, int numero, List<(double, double)> points});

/// Lit les formes numérotées d'un fichier KML.
List<FormeKml> lireKml(String kml) {
  final formes = <FormeKml>[];
  for (final placemark in RegExp(r'<Placemark\b.*?</Placemark>', dotAll: true).allMatches(kml)) {
    final bloc = placemark[0]!;
    final nom = _texte(RegExp(r'<name>(.*?)</name>', dotAll: true).firstMatch(bloc)?[1] ?? '');
    final numero = int.tryParse(RegExp(r'\d+').firstMatch(nom)?[0] ?? '');
    if (numero == null) continue;
    // Polygone : son contour extérieur ; sinon une ligne (tracé fermé à la main).
    final bord = RegExp(r'<outerBoundaryIs>.*?<coordinates>(.*?)</coordinates>', dotAll: true).firstMatch(bloc) ??
        RegExp(r'<LineString>.*?<coordinates>(.*?)</coordinates>', dotAll: true).firstMatch(bloc);
    if (bord == null) continue;
    final points = [
      for (final triplet in bord[1]!.trim().split(RegExp(r'\s+')))
        if (triplet.split(',') case [final lon, final lat, ...]) (double.parse(lat), double.parse(lon)),
    ];
    if (points.length >= 3) formes.add((nom: nom, numero: numero, points: points));
  }
  return formes;
}

/// Texte d'un élément XML : sans CDATA ni entités courantes.
String _texte(String brut) => brut
    .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&apos;', "'")
    .replaceAll('&quot;', '"')
    .trim();
