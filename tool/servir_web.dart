// Sert la version de production (build/web) sur http://localhost:8080,
// pour tester l'app compilée comme sur l'iPhone.
//
//   flutter build web --release
//   dart run tool/servir_web.dart            (ou --port 9000)
//
// N'utilise que la bibliothèque standard de Dart.

// Script en ligne de commande : print est la sortie normale.
// ignore_for_file: avoid_print

import 'dart:io';

const _types = {
  'html': 'text/html; charset=utf-8',
  'js': 'text/javascript; charset=utf-8',
  'mjs': 'text/javascript; charset=utf-8',
  'json': 'application/json; charset=utf-8',
  'wasm': 'application/wasm',
  'css': 'text/css; charset=utf-8',
  'png': 'image/png',
  'ico': 'image/x-icon',
  'svg': 'image/svg+xml',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
  'woff2': 'font/woff2',
  'bin': 'application/octet-stream',
};

Future<void> main(List<String> args) async {
  final i = args.indexOf('--port');
  final port = i >= 0 && i + 1 < args.length ? int.parse(args[i + 1]) : 8080;
  final racine = Directory.fromUri(Platform.script.resolve('../build/web/'));
  if (!File('${racine.path}index.html').existsSync()) {
    stderr.writeln('build/web introuvable : lancez d\'abord « flutter build web --release ».');
    exit(1);
  }

  final serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('App servie sur http://localhost:$port (Ctrl+C pour arrêter)');

  await for (final req in serveur) {
    var chemin = Uri.decodeComponent(req.uri.path);
    if (chemin.endsWith('/')) chemin += 'index.html';
    final fichier = File('${racine.path}${chemin.substring(1)}');
    // Refuse de sortir du dossier build/web.
    final dansRacine = fichier.absolute.path.startsWith(racine.absolute.path);
    final res = req.response..headers.set('Cache-Control', 'no-cache');
    if (!dansRacine || !fichier.existsSync()) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      print('404 $chemin');
      continue;
    }
    final ext = chemin.contains('.') ? chemin.split('.').last : '';
    res.headers.set(HttpHeaders.contentTypeHeader, _types[ext] ?? 'application/octet-stream');
    await res.addStream(fichier.openRead());
    await res.close();
  }
}
