// Génère les icônes de l'app à partir du logo GEOSECTOR
// (tool/icones/logo_geosector.webp) :
//
//   flutter test tool/icones/logo_icones_test.dart
//
// - production (web/icons/) : le logo sur fond blanc ;
// - test (web/icons/test/) : le même logo avec un cadre et un bandeau orange,
//   pour ne jamais confondre les deux apps sur le téléphone ;
// - « maskable » (Android peut rogner les bords) : logo réduit à 80 %.
//
// Passe par flutter test pour profiter du moteur de dessin de Flutter
// (dart:ui), sans dépendance supplémentaire.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _source = 'tool/icones/logo_geosector.webp';
const _orange = Color(0xFFEF6C00);

Future<ui.Image> _chargerLogo() async {
  final codec = await ui.instantiateImageCodec(File(_source).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<void> _ecrire(String chemin, int taille, ui.Image logo, {bool test = false, double echelle = 1}) async {
  final enregistreur = ui.PictureRecorder();
  final canvas = Canvas(enregistreur);
  final s = taille.toDouble();
  canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = const Color(0xFFFFFFFF));

  // Logo centré ; en test, un peu plus petit pour laisser la place au bandeau.
  final cote = s * echelle * (test ? 0.82 : 1);
  final haut = test ? (s - cote) / 2 - s * 0.06 : (s - cote) / 2;
  canvas.drawImageRect(
    logo,
    Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
    Rect.fromLTWH((s - cote) / 2, haut, cote, cote),
    Paint()..filterQuality = FilterQuality.high,
  );

  if (test) {
    final m = s * (1 - echelle) / 2; // marge des icônes « maskable »
    final interieur = Rect.fromLTWH(m, m, s - 2 * m, s - 2 * m);
    // Bandeau orange en bas et cadre orange.
    canvas.drawRect(
      Rect.fromLTWH(interieur.left, interieur.bottom - interieur.height * 0.14, interieur.width, interieur.height * 0.14),
      Paint()..color = _orange,
    );
    canvas.drawRect(
      interieur.deflate(interieur.width * 0.03),
      Paint()
        ..color = _orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = interieur.width * 0.06,
    );
  }

  final image = await enregistreur.endRecording().toImage(taille, taille);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(chemin)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('génère les icônes à partir du logo', () async {
    final logo = await _chargerLogo();
    for (final (dossier, test) in [('web/icons', false), ('web/icons/test', true)]) {
      await _ecrire('$dossier/Icon-192.png', 192, logo, test: test);
      await _ecrire('$dossier/Icon-512.png', 512, logo, test: test);
      await _ecrire('$dossier/Icon-maskable-192.png', 192, logo, test: test, echelle: 0.8);
      await _ecrire('$dossier/Icon-maskable-512.png', 512, logo, test: test, echelle: 0.8);
      await _ecrire('$dossier/apple-touch-icon.png', 180, logo, test: test);
      await _ecrire('$dossier/favicon.png', 64, logo, test: test);
    }
  });
}
