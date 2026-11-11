// Génère build/web/sw.js (notre service worker) à partir de tool/sw_modele.js.
// À lancer APRÈS « flutter build web » :
//
//   flutter build web --release --no-web-resources-cdn
//   dart run tool/generer_sw.dart
//
// Liste les fichiers à mettre en cache, calcule une version (empreinte du
// contenu) et supprime le service worker de Flutter (déprécié, inutile).
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

void main() {
  final racine = Directory.fromUri(Platform.script.resolve('../'));
  final build = Directory('${racine.path}build/web/');
  final modele = File('${racine.path}tool/sw_modele.js');
  if (!File('${build.path}index.html').existsSync()) {
    stderr.writeln('build/web introuvable : lancez d\'abord « flutter build web ».');
    exit(1);
  }

  // Le service worker de Flutter ne sert plus à rien (il se désinscrit seul).
  final swFlutter = File('${build.path}flutter_service_worker.js');
  if (swFlutter.existsSync()) swFlutter.deleteSync();

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
      .toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));

  if (!tous.any((e) => e.$2 == 'canvaskit/canvaskit.wasm')) {
    stderr.writeln(
      'canvaskit/canvaskit.wasm absent de build/web : construisez avec '
      '« --no-web-resources-cdn », sinon l\'app dépend des serveurs Google (ARCHITECTURE §7.2).',
    );
    exit(1);
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
  const marqueurVersion = "const VERSION = '__VERSION__';";
  const marqueurFichiers = 'const FICHIERS = __FICHIERS__;';
  final texteModele = modele.readAsStringSync();
  if (!texteModele.contains(marqueurVersion) || !texteModele.contains(marqueurFichiers)) {
    stderr.writeln('tool/sw_modele.js : marqueurs de version ou de fichiers introuvables.');
    exit(1);
  }
  final sw = texteModele
      .replaceFirst(marqueurVersion, "const VERSION = '$version';")
      .replaceFirst(
        marqueurFichiers,
        'const FICHIERS = ${const JsonEncoder.withIndent('  ').convert(fichiers)};',
      );
  File('${build.path}sw.js').writeAsStringSync(sw);

  print('sw.js écrit : version $version');
  print('${fichiers.length} fichiers pré-cachés, ${(taille / 1024 / 1024).toStringAsFixed(1)} Mo');
}
