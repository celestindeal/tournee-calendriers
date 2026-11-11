// Génère build/web/sw.js (notre service worker) à partir de tool/sw_modele.js.
// À lancer APRÈS « flutter build web » :
//
//   flutter build web --release --no-web-resources-cdn --dart-define=ENV=prod
//   dart run tool/generer_sw.dart --environnement prod      (ou test)
//
// Liste les fichiers à mettre en cache, calcule une version (empreinte du
// contenu) et supprime le service worker de Flutter (déprécié, inutile).
// Pour l'environnement de test : caches préfixés « test- », et nom « TEST »
// + couleur orange dans manifest.json et index.html (icône de l'iPhone).
// N'utilise que la bibliothèque standard de Dart.

// Script en ligne de commande : print est la sortie normale.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Fichiers de build/web à NE PAS mettre en cache à l'installation.
bool _exclu(String chemin) =>
    chemin == 'sw.js' ||
    chemin == 'flutter_service_worker.js' ||
    chemin.startsWith('.') ||
    chemin.endsWith('.map') ||
    chemin.endsWith('.symbols') ||
    // Moteur de rendu : Safari charge toujours la variante complète
    // canvaskit/canvaskit.{js,wasm} (voir flutter.js). Les autres variantes
    // servent à Chrome (chromium, webparagraph) ou aux builds WebAssembly
    // (skwasm, wimp, ARCHITECTURE §7.3) ; Chrome les mettra en cache à la
    // première utilisation.
    (chemin.startsWith('canvaskit/') &&
        chemin != 'canvaskit/canvaskit.js' &&
        chemin != 'canvaskit/canvaskit.wasm');

/// Réglages propres à chaque environnement.
const _environnements = {
  // Production : à la racine du site ; ne sert pas le sous-dossier de test.
  'prod': (prefixe: '', ignores: ['test/']),
  // Test : dans …/test/, caches séparés de ceux de la production.
  'test': (prefixe: 'test-', ignores: <String>[]),
};

Never _erreur(String message) {
  stderr.writeln('Erreur : $message');
  exit(1);
}

void main(List<String> args) {
  final i = args.indexOf('--environnement');
  final environnement = i >= 0 && i + 1 < args.length ? args[i + 1] : 'prod';
  final reglages =
      _environnements[environnement] ?? _erreur('environnement inconnu « $environnement » (prod ou test)');

  final racine = Directory.fromUri(Platform.script.resolve('../'));
  final build = Directory('${racine.path}build/web/');
  final modele = File('${racine.path}tool/sw_modele.js');
  if (!File('${build.path}index.html').existsSync()) {
    _erreur('build/web introuvable : lancez d\'abord « flutter build web ».');
  }

  // Le service worker de Flutter ne sert plus à rien (il se désinscrit seul).
  final swFlutter = File('${build.path}flutter_service_worker.js');
  if (swFlutter.existsSync()) swFlutter.deleteSync();

  if (environnement != 'prod') _marquerCommeTest(build);

  final fichiers = <String>[];
  var taille = 0;
  var empreinte = 0x811c9dc5; // FNV-1a 32 bits sur chemins + contenus
  void melanger(List<int> octets) {
    for (final o in octets) {
      empreinte ^= o;
      empreinte = (empreinte * 0x01000193) & 0xffffffff;
    }
  }

  final tous = build
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => (f, f.path.substring(build.path.length).replaceAll('\\', '/')))
      .where((e) => !_exclu(e.$2))
      // Jamais les fichiers d'un autre environnement (ex. test/ en production).
      .where((e) => !reglages.ignores.any((dossier) => e.$2.startsWith(dossier)))
      .toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));

  if (!tous.any((e) => e.$2 == 'canvaskit/canvaskit.wasm')) {
    _erreur(
      'canvaskit/canvaskit.wasm absent de build/web : construisez avec '
      '« --no-web-resources-cdn », sinon l\'app dépend des serveurs Google (ARCHITECTURE §7.2).',
    );
  }

  for (final (fichier, chemin) in tous) {
    final octets = fichier.readAsBytesSync();
    melanger(utf8.encode(chemin));
    melanger(octets);
    taille += octets.length;
    fichiers.add(chemin);
  }
  // L'adresse de l'app sans « index.html » (ouverture depuis l'icône).
  fichiers.insert(0, './');

  final version = empreinte.toRadixString(16).padLeft(8, '0');
  final remplacements = {
    "const VERSION = '__VERSION__';": "const VERSION = '$version';",
    "const PREFIXE = '__PREFIXE__';": "const PREFIXE = '${reglages.prefixe}';",
    'const IGNORES = __IGNORES__;': 'const IGNORES = ${jsonEncode(reglages.ignores)};',
    'const FICHIERS = __FICHIERS__;': 'const FICHIERS = ${const JsonEncoder.withIndent('  ').convert(fichiers)};',
  };
  var sw = modele.readAsStringSync();
  for (final MapEntry(key: marqueur, value: valeur) in remplacements.entries) {
    if (!sw.contains(marqueur)) _erreur('tool/sw_modele.js : marqueur « $marqueur » introuvable.');
    sw = sw.replaceFirst(marqueur, valeur);
  }
  File('${build.path}sw.js').writeAsStringSync(sw);

  print('sw.js écrit : environnement $environnement, version $version');
  print('${fichiers.length} fichiers pré-cachés, ${(taille / 1024 / 1024).toStringAsFixed(1)} Mo');
}

/// Environnement de test : nom « TEST », couleur et icônes orange (dessinées
/// dans web/icons/test/), pour ne jamais confondre avec l'app de la tournée.
void _marquerCommeTest(Directory build) {
  final fManifest = File('${build.path}manifest.json');
  final manifest = jsonDecode(fManifest.readAsStringSync()) as Map<String, dynamic>
    ..['name'] = 'Tournée TEST'
    ..['short_name'] = 'TEST'
    ..['theme_color'] = '#EF6C00';
  for (final icone in (manifest['icons'] as List).cast<Map<String, dynamic>>()) {
    icone['src'] = (icone['src'] as String).replaceFirst('icons/', 'icons/test/');
  }
  fManifest.writeAsStringSync(const JsonEncoder.withIndent('    ').convert(manifest));

  final fIndex = File('${build.path}index.html');
  var index = fIndex.readAsStringSync();
  const remplacements = {
    '<title>Tournée calendriers</title>': '<title>Tournée TEST</title>',
    '<meta name="apple-mobile-web-app-title" content="Tournée">':
        '<meta name="apple-mobile-web-app-title" content="TEST">',
    '<meta name="theme-color" content="#C62828">': '<meta name="theme-color" content="#EF6C00">',
    '<link rel="apple-touch-icon" href="icons/apple-touch-icon.png">':
        '<link rel="apple-touch-icon" href="icons/test/apple-touch-icon.png">',
    '<link rel="icon" type="image/png" href="icons/favicon.png"/>':
        '<link rel="icon" type="image/png" href="icons/test/favicon.png"/>',
  };
  for (final MapEntry(key: avant, value: apres) in remplacements.entries) {
    if (!index.contains(avant)) _erreur('web/index.html : « $avant » introuvable.');
    index = index.replaceFirst(avant, apres);
  }
  fIndex.writeAsStringSync(index);
}
