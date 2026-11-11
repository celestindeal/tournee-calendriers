// Dessine les icônes de l'app (calendrier sur fond rouge pompier ; fond
// orange pour l'environnement de test) et les écrit dans web/icons/ et
// web/icons/test/. À relancer seulement si l'on change le dessin :
//
//   flutter test tool/icones/dessiner_icones_test.dart
//
// (Lancé comme un test pour profiter du moteur de dessin de Flutter ; ce
// fichier est hors de test/, donc pas exécuté avec les tests habituels.)

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Couleurs d'une variante de l'icône.
class _Theme {
  const _Theme(this.fondHaut, this.fondBas, this.bandeau);
  final Color fondHaut, fondBas, bandeau;
}

const _production = _Theme(Color(0xFFE53935), Color(0xFFB71C1C), Color(0xFFFFC107));
const _test = _Theme(Color(0xFFFFA726), Color(0xFFE65100), Color(0xFF37474F));

/// Dessine l'icône dans un carré de côté [s]. [echelle] < 1 réduit le motif
/// (icônes « maskable », dont les bords peuvent être rognés par le téléphone).
void _dessiner(Canvas canvas, double s, _Theme t, {double echelle = 1}) {
  // Fond plein (iOS arrondit lui-même les coins ; pas de transparence).
  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s), [t.fondHaut, t.fondBas]),
  );

  canvas.save();
  canvas.translate(s / 2, s / 2);
  canvas.scale(echelle);
  canvas.translate(-s / 2, -s / 2);

  // Calendrier : ombre, corps blanc, bandeau.
  final corps = RRect.fromRectAndRadius(Rect.fromLTWH(0.19 * s, 0.25 * s, 0.62 * s, 0.56 * s), Radius.circular(0.07 * s));
  canvas.drawRRect(corps.shift(Offset(0, 0.02 * s)), Paint()..color = const Color(0x40000000));
  canvas.drawRRect(corps, Paint()..color = const Color(0xFFFFFFFF));
  canvas.save();
  canvas.clipRRect(corps);
  canvas.drawRect(Rect.fromLTWH(0.19 * s, 0.25 * s, 0.62 * s, 0.15 * s), Paint()..color = t.bandeau);
  canvas.restore();

  // Anneaux.
  for (final x in [0.35, 0.65]) {
    final anneau = RRect.fromRectAndRadius(Rect.fromLTWH((x - 0.03) * s, 0.19 * s, 0.06 * s, 0.13 * s), Radius.circular(0.03 * s));
    canvas.drawRRect(anneau, Paint()..color = const Color(0xFFECEFF1));
    canvas.drawRRect(
      anneau,
      Paint()
        ..color = const Color(0xFF455A64)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.012 * s,
    );
  }

  // Grille de jours : 4 × 3 cases ; quelques-unes « faites » (vert) ou « à repasser » (orange).
  const vert = Color(0xFF2E7D32), orange = Color(0xFFEF6C00), gris = Color(0xFFE0E0E0);
  final couleurs = [
    [vert, vert, gris, gris],
    [vert, orange, gris, gris],
    [gris, gris, gris, gris],
  ];
  const cote = 0.105, ecart = 0.035, gauche = 0.255, haut = 0.45;
  for (var ligne = 0; ligne < 3; ligne++) {
    for (var col = 0; col < 4; col++) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH((gauche + col * (cote + ecart)) * s, (haut + ligne * (cote + ecart)) * s, cote * s, cote * s),
        Radius.circular(0.02 * s),
      );
      canvas.drawRRect(r, Paint()..color = couleurs[ligne][col]);
    }
  }

  // Grande coche verte sur le calendrier : « tournée faite ».
  final coche = Path()
    ..moveTo(0.53 * s, 0.70 * s)
    ..lineTo(0.62 * s, 0.79 * s)
    ..lineTo(0.84 * s, 0.53 * s);
  canvas.drawPath(
    coche,
    Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.11 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(
    coche,
    Paint()
      ..color = vert
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.065 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  canvas.restore();
}

Future<void> _ecrire(String chemin, int taille, _Theme t, {double echelle = 1}) async {
  final enregistreur = ui.PictureRecorder();
  _dessiner(Canvas(enregistreur), taille.toDouble(), t, echelle: echelle);
  final image = await enregistreur.endRecording().toImage(taille, taille);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(chemin)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dessine les icônes de l\'app', () async {
    for (final (dossier, theme) in [('web/icons', _production), ('web/icons/test', _test)]) {
      await _ecrire('$dossier/Icon-192.png', 192, theme);
      await _ecrire('$dossier/Icon-512.png', 512, theme);
      // Maskable : motif réduit à 80 % (zone sûre des icônes adaptatives).
      await _ecrire('$dossier/Icon-maskable-192.png', 192, theme, echelle: 0.8);
      await _ecrire('$dossier/Icon-maskable-512.png', 512, theme, echelle: 0.8);
      // iPhone : 180 × 180 (écran d'accueil).
      await _ecrire('$dossier/apple-touch-icon.png', 180, theme);
      await _ecrire('$dossier/favicon.png', 64, theme);
    }
  });
}
