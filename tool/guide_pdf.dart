// Génère le guide d'utilisation imprimable (PDF) pour les membres de la
// caserne : docs/guide/Guide_Tournee_Calendriers.pdf
//
//   dart run tool/guide_pdf.dart
//
// Captures d'écran : docs/guide/captures/ (app de démonstration, données
// fictives, au format téléphone 390 × 780). Les étapes d'installation propres
// à Safari et Chrome sont dessinées (illustrations simplifiées).

// Script en ligne de commande : print est la sortie normale.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _url = 'https://celestindeal.github.io/tournee-calendriers/';
const _urlAffichee = 'celestindeal.github.io/tournee-calendriers';
const _sortie = 'docs/guide/Guide_Tournee_Calendriers.pdf';
const _captures = 'docs/guide/captures';

// Couleurs (celles de l'app).
const _rouge = PdfColor.fromInt(0xFFC62828);
const _rougeFonce = PdfColor.fromInt(0xFF8E2A2A);
const _vert = PdfColor.fromInt(0xFF2E7D32);
const _orange = PdfColor.fromInt(0xFFEF6C00);
const _bleu = PdfColor.fromInt(0xFF1565C0);
const _gris = PdfColor.fromInt(0xFF9E9E9E);
const _violet = PdfColor.fromInt(0xFF6A1B9A);
const _fondDoux = PdfColor.fromInt(0xFFFFF3E0);
const _fondGris = PdfColor.fromInt(0xFFF2F2F2);
const _texteDoux = PdfColor.fromInt(0xFF555555);
const _bleuIos = PdfColor.fromInt(0xFF007AFF);

late pw.Font _normal, _gras, _moyen;

Future<void> main() async {
  _normal = pw.Font.ttf(File('assets/fonts/roboto/Roboto-Regular.ttf').readAsBytesSync().buffer.asByteData());
  _gras = pw.Font.ttf(File('assets/fonts/roboto/Roboto-Bold.ttf').readAsBytesSync().buffer.asByteData());
  _moyen = pw.Font.ttf(File('assets/fonts/roboto/Roboto-Medium.ttf').readAsBytesSync().buffer.asByteData());

  final doc = pw.Document(
    title: 'Tournée des calendriers – Mode d\'emploi',
    author: 'Amicale des sapeurs-pompiers',
    theme: pw.ThemeData.withFont(base: _normal, bold: _gras),
  );

  final pages = [
    _couverture,
    _installerIphone,
    _installerAndroid,
    _ecranPrincipal,
    _choisirTournee,
    _marquerMaison,
    _memosItineraire,
    _retrouverMaison,
    _bonASavoir,
  ];
  for (final (i, page) in pages.indexed) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 36, 42, 30),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: page()),
          if (i > 0) _piedDePage(i + 1, pages.length),
        ],
      ),
    ));
  }

  final fichier = File(_sortie)..parent.createSync(recursive: true);
  fichier.writeAsBytesSync(await doc.save());
  print('$_sortie : ${pages.length} pages, ${fichier.lengthSync() ~/ 1024} Ko.');
}

// --- Briques de mise en page ------------------------------------------------

pw.Widget _titre(String texte, {String? numero}) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 14),
  child: pw.Row(
    children: [
      if (numero != null) ...[
        pw.Container(
          width: 34,
          height: 34,
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(color: _rouge, shape: pw.BoxShape.circle),
          child: pw.Text(numero, style: pw.TextStyle(font: _gras, fontSize: 18, color: PdfColors.white)),
        ),
        pw.SizedBox(width: 12),
      ],
      pw.Expanded(child: pw.Text(texte, style: pw.TextStyle(font: _gras, fontSize: 24, color: _rougeFonce))),
    ],
  ),
);

pw.Widget _texte(String texte, {double taille = 13, PdfColor? couleur, pw.Font? police}) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Text(texte, style: pw.TextStyle(font: police ?? _normal, fontSize: taille, color: couleur, lineSpacing: 2.5)),
);

/// Texte avec des passages en gras : « Touchez **Partager** ».
pw.Widget _riche(String texte, {double taille = 13}) {
  final morceaux = <pw.TextSpan>[];
  final parties = texte.split('**');
  for (final (i, p) in parties.indexed) {
    morceaux.add(pw.TextSpan(text: p, style: pw.TextStyle(font: i.isOdd ? _gras : _normal)));
  }
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.RichText(text: pw.TextSpan(style: pw.TextStyle(fontSize: taille, lineSpacing: 2.5), children: morceaux)),
  );
}

/// Étape numérotée : pastille, texte (avec **gras**), illustration éventuelle.
pw.Widget _etape(int n, String texte, {pw.Widget? illustration}) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 10),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _pastille(n, taille: 24),
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: _riche(texte)),
            if (illustration != null) pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: illustration),
          ],
        ),
      ),
    ],
  ),
);

pw.Widget _pastille(int n, {double taille = 22, PdfColor couleur = _rouge}) => pw.Container(
  width: taille,
  height: taille,
  alignment: pw.Alignment.center,
  decoration: pw.BoxDecoration(
    color: couleur,
    shape: pw.BoxShape.circle,
    border: pw.Border.all(color: PdfColors.white, width: 1.5),
  ),
  child: pw.Text('$n', style: pw.TextStyle(font: _gras, fontSize: taille * 0.55, color: PdfColors.white)),
);

/// Encadré coloré (conseil, attention).
pw.Widget _encadre(String titre, String texte, {PdfColor couleur = _orange, PdfColor fond = _fondDoux}) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
  padding: const pw.EdgeInsets.all(10),
  decoration: pw.BoxDecoration(
    color: fond,
    border: pw.Border(left: pw.BorderSide(color: couleur, width: 4)),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(titre, style: pw.TextStyle(font: _gras, fontSize: 13, color: couleur)),
      pw.SizedBox(height: 3),
      _riche(texte, taille: 12),
    ],
  ),
);

/// Capture d'écran du téléphone (390 × 780), avec des pastilles numérotées
/// placées aux coordonnées de la capture.
pw.Widget _capture(String nom, {double largeur = 165, List<(double, double, int)> reperes = const [], String? legende}) {
  final image = pw.MemoryImage(File('$_captures/$nom').readAsBytesSync());
  final echelle = largeur / 390;
  final hauteur = 780 * echelle;
  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Container(
        width: largeur + 8,
        height: hauteur + 8,
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(
          color: PdfColors.black,
          borderRadius: pw.BorderRadius.circular(14),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 10,
          verticalRadius: 10,
          child: pw.Stack(
            children: [
              pw.Image(image, width: largeur, height: hauteur, fit: pw.BoxFit.fill),
              for (final (x, y, n) in reperes)
                pw.Positioned(left: x * echelle - 11, top: y * echelle - 11, child: _pastille(n)),
            ],
          ),
        ),
      ),
      if (legende != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.SizedBox(
            width: largeur + 8,
            child: pw.Text(legende, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, color: _texteDoux)),
          ),
        ),
    ],
  );
}

/// Liste de repères : pastille + explication.
pw.Widget _reperes(List<(int, String)> lignes) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    for (final (n, texte) in lignes)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 9),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _pastille(n),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: _riche(texte, taille: 12.5))),
          ],
        ),
      ),
  ],
);

pw.Widget _piedDePage(int page, int total) => pw.Container(
  padding: const pw.EdgeInsets.only(top: 6),
  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _fondGris, width: 1))),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text('Tournée des calendriers – mode d\'emploi', style: pw.TextStyle(fontSize: 9, color: _texteDoux)),
      pw.Text('$_urlAffichee   ·   page $page / $total', style: pw.TextStyle(fontSize: 9, color: _texteDoux)),
    ],
  ),
);

// --- Petits dessins (icônes et écrans simplifiés) ----------------------------

/// Icône « Partager » d'iOS : carré ouvert en haut, flèche vers le haut.
pw.Widget _iconePartager({double taille = 26, PdfColor couleur = _bleuIos}) => pw.CustomPaint(
  size: PdfPoint(taille, taille),
  painter: (canvas, size) {
    final w = size.x, h = size.y;
    canvas
      ..setStrokeColor(couleur)
      ..setLineWidth(w * 0.07)
      ..setLineCap(PdfLineCap.round)
      ..setLineJoin(PdfLineJoin.round)
      // Boîte ouverte.
      ..moveTo(w * 0.36, h * 0.62)
      ..lineTo(w * 0.22, h * 0.62)
      ..lineTo(w * 0.22, h * 0.08)
      ..lineTo(w * 0.78, h * 0.08)
      ..lineTo(w * 0.78, h * 0.62)
      ..lineTo(w * 0.64, h * 0.62)
      // Flèche.
      ..moveTo(w * 0.5, h * 0.30)
      ..lineTo(w * 0.5, h * 0.94)
      ..moveTo(w * 0.36, h * 0.80)
      ..lineTo(w * 0.5, h * 0.94)
      ..lineTo(w * 0.64, h * 0.80)
      ..strokePath();
  },
);

/// Icône « Sur l'écran d'accueil » : carré arrondi avec un « + ».
pw.Widget _iconeAjouter({double taille = 22, PdfColor couleur = PdfColors.black}) => pw.CustomPaint(
  size: PdfPoint(taille, taille),
  painter: (canvas, size) {
    final w = size.x, h = size.y;
    canvas
      ..setStrokeColor(couleur)
      ..setLineWidth(w * 0.07)
      ..setLineCap(PdfLineCap.round)
      ..drawRRect(w * 0.1, h * 0.1, w * 0.8, h * 0.8, w * 0.18, h * 0.18)
      ..moveTo(w * 0.5, h * 0.3)
      ..lineTo(w * 0.5, h * 0.7)
      ..moveTo(w * 0.3, h * 0.5)
      ..lineTo(w * 0.7, h * 0.5)
      ..strokePath();
  },
);

/// Trois points verticaux (menu de Chrome).
pw.Widget _iconeTroisPoints({double taille = 22, PdfColor couleur = PdfColors.black}) => pw.CustomPaint(
  size: PdfPoint(taille, taille),
  painter: (canvas, size) {
    canvas.setFillColor(couleur);
    for (final y in [0.22, 0.5, 0.78]) {
      canvas.drawEllipse(size.x / 2, size.y * y, size.x * 0.08, size.x * 0.08);
    }
    canvas.fillPath();
  },
);

/// Icône « onglets » de Safari : deux carrés décalés.
pw.Widget _iconeOnglets({double taille = 16, PdfColor couleur = _bleuIos}) => pw.CustomPaint(
  size: PdfPoint(taille, taille),
  painter: (canvas, size) {
    final w = size.x, h = size.y;
    canvas
      ..setStrokeColor(couleur)
      ..setLineWidth(w * 0.08)
      ..drawRRect(w * 0.1, h * 0.1, w * 0.6, h * 0.6, w * 0.1, h * 0.1)
      ..moveTo(w * 0.3, h * 0.9)
      ..lineTo(w * 0.9, h * 0.9)
      ..lineTo(w * 0.9, h * 0.3)
      ..strokePath();
  },
);

/// La vraie icône de l'app, avec son nom, comme sur l'écran d'accueil.
pw.Widget _iconeApp() => pw.Container(
  padding: const pw.EdgeInsets.all(8),
  decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFF37474F), borderRadius: pw.BorderRadius.circular(10)),
  child: pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.ClipRRect(
        horizontalRadius: 9,
        verticalRadius: 9,
        child: pw.Image(pw.MemoryImage(File('web/icons/Icon-192.png').readAsBytesSync()), width: 40, height: 40),
      ),
      pw.SizedBox(height: 3),
      pw.Text('Tournée', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
    ],
  ),
);

/// Partie agrandie d'une capture (bande horizontale de [hauteurSource] pixels
/// à partir de [haut]), avec des pastilles aux coordonnées de la capture.
pw.Widget _recadrage(
  String nom, {
  required double haut,
  required double hauteurSource,
  required double largeur,
  List<(double, double, int)> reperes = const [],
}) {
  final s = largeur / 390;
  final image = pw.MemoryImage(File('$_captures/$nom').readAsBytesSync());
  return pw.Container(
    width: largeur + 6,
    height: hauteurSource * s + 6,
    padding: const pw.EdgeInsets.all(3),
    decoration: pw.BoxDecoration(color: PdfColors.black, borderRadius: pw.BorderRadius.circular(8)),
    child: pw.ClipRRect(
      horizontalRadius: 6,
      verticalRadius: 6,
      child: pw.Stack(
        overflow: pw.Overflow.clip,
        children: [
          pw.Positioned(
            left: 0,
            top: -haut * s,
            child: pw.Image(image, width: largeur, height: 780 * s, fit: pw.BoxFit.fill),
          ),
          for (final (x, y, n) in reperes)
            pw.Positioned(left: x * s - 11, top: (y - haut) * s - 11, child: _pastille(n)),
        ],
      ),
    ),
  );
}

/// Cadre de téléphone simplifié autour d'un contenu dessiné.
pw.Widget _telephone(pw.Widget contenu, {double largeur = 190, double hauteur = 120}) => pw.Container(
  width: largeur,
  height: hauteur,
  padding: const pw.EdgeInsets.all(5),
  decoration: pw.BoxDecoration(
    color: PdfColors.black,
    borderRadius: pw.BorderRadius.circular(12),
  ),
  child: pw.ClipRRect(
    horizontalRadius: 8,
    verticalRadius: 8,
    child: pw.Container(color: PdfColors.white, child: contenu),
  ),
);

/// Cercle de mise en évidence autour d'un élément dessiné.
pw.Widget _entoure(pw.Widget enfant) => pw.Container(
  padding: const pw.EdgeInsets.all(3),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: _rouge, width: 2.5),
    borderRadius: pw.BorderRadius.circular(10),
  ),
  child: enfant,
);

/// Ligne de menu dessinée (texte + icône), éventuellement mise en évidence.
pw.Widget _ligneMenu(String texte, {pw.Widget? icone, bool evidence = false}) {
  final ligne = pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pw.BoxDecoration(color: evidence ? PdfColors.white : _fondGris),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(texte, style: pw.TextStyle(fontSize: 10.5, font: evidence ? _gras : _normal))),
        ?icone,
      ],
    ),
  );
  return evidence ? _entoure(ligne) : ligne;
}

// --- Pages ------------------------------------------------------------------

pw.Widget _couverture() {
  final icone = pw.MemoryImage(File('web/icons/Icon-512.png').readAsBytesSync());
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.SizedBox(height: 10),
      pw.ClipRRect(horizontalRadius: 20, verticalRadius: 20, child: pw.Image(icone, width: 90, height: 90)),
      pw.SizedBox(height: 14),
      pw.Text('Tournée des calendriers', style: pw.TextStyle(font: _gras, fontSize: 32, color: _rougeFonce)),
      pw.Text('Mode d\'emploi de l\'application', style: pw.TextStyle(font: _moyen, fontSize: 18, color: _texteDoux)),
      pw.SizedBox(height: 16),
      pw.SizedBox(
        width: 430,
        child: pw.Text(
          'Sur le téléphone, une carte montre toutes les maisons de la tournée. '
          'On touche une maison, on choisit : acheté, à repasser, refus… '
          'La maison prend une couleur, et toute l\'équipe voit ce qui est fait et ce qui reste à faire.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 13.5, lineSpacing: 3),
        ),
      ),
      pw.SizedBox(height: 22),
      // Adresse et QR code.
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _rouge, width: 2),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: _url, width: 120, height: 120),
            pw.SizedBox(width: 18),
            pw.SizedBox(
              width: 300,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('L\'adresse de l\'application', style: pw.TextStyle(font: _gras, fontSize: 15, color: _rougeFonce)),
                  pw.SizedBox(height: 6),
                  pw.Text(_urlAffichee, style: pw.TextStyle(font: _gras, fontSize: 13.5)),
                  pw.SizedBox(height: 8),
                  _riche('Visez le carré avec **l\'appareil photo** du téléphone, puis touchez le lien qui apparaît. '
                      'Ou tapez l\'adresse dans **Safari** (iPhone) ou **Chrome** (Android).', taille: 11.5),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 18),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          for (final t in ['Gratuit', 'Aucun compte', 'Aucun mot de passe', 'Marche sans réseau'])
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 4),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(color: _fondDoux, borderRadius: pw.BorderRadius.circular(12)),
              child: pw.Text(t, style: pw.TextStyle(font: _moyen, fontSize: 11, color: _rougeFonce)),
            ),
        ],
      ),
      pw.SizedBox(height: 22),
      pw.Container(
        width: 430,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Dans ce guide', style: pw.TextStyle(font: _gras, fontSize: 15, color: _rougeFonce)),
            pw.SizedBox(height: 6),
            for (final (n, t) in [
              (1, 'Installer l\'application sur un iPhone'),
              (2, 'Installer l\'application sur un téléphone Android'),
              (3, 'L\'écran principal'),
              (4, 'Choisir sa tournée'),
              (5, 'Marquer une maison'),
              (6, 'Mémos et itinéraire'),
              (7, 'Retrouver une maison'),
              (8, 'Bon à savoir'),
            ])
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Row(children: [
                  pw.SizedBox(width: 22, child: pw.Text('$n.', style: pw.TextStyle(font: _gras, fontSize: 12.5))),
                  pw.Text(t, style: const pw.TextStyle(fontSize: 12.5)),
                  pw.Spacer(),
                  pw.Text('page ${n + 1}', style: pw.TextStyle(fontSize: 11, color: _texteDoux)),
                ]),
              ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _installerIphone() => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _titre('Installer l\'application sur un iPhone', numero: '1'),
    _texte('À faire une seule fois. L\'application s\'ajoute à l\'écran d\'accueil, avec une icône rouge, '
        'comme une application normale.'),
    pw.SizedBox(height: 6),
    _etape(1, 'Ouvrez **Safari** (la boussole bleue) et allez à l\'adresse **$_urlAffichee**. '
        'Ou visez le QR code de la première page avec l\'appareil photo.'),
    _etape(
      2,
      'Touchez le bouton **Partager** : un carré avec une flèche vers le haut, en bas de l\'écran. '
      'Sur les iPhone récents, il peut se trouver dans le menu « … » en bas à droite.',
      illustration: _telephone(
        pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Expanded(child: pw.Container(color: _fondGris, alignment: pw.Alignment.center, child: pw.Text('page de l\'application', style: pw.TextStyle(fontSize: 9, color: _texteDoux)))),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              color: PdfColors.white,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  pw.Text('‹', style: pw.TextStyle(fontSize: 18, color: _bleuIos)),
                  pw.Text('›', style: pw.TextStyle(fontSize: 18, color: _gris)),
                  _entoure(_iconePartager(taille: 20)),
                  _iconeOnglets(taille: 16),
                ],
              ),
            ),
          ],
        ),
        largeur: 200,
        hauteur: 95,
      ),
    ),
    _etape(
      3,
      'Faites défiler la liste vers le bas et touchez **Sur l\'écran d\'accueil**.',
      illustration: _telephone(
        pw.Column(
          children: [
            _ligneMenu('Copier'),
            pw.SizedBox(height: 2),
            _ligneMenu('Ajouter aux favoris'),
            pw.SizedBox(height: 2),
            _ligneMenu('Sur l\'écran d\'accueil', icone: _iconeAjouter(taille: 16), evidence: true),
            pw.SizedBox(height: 2),
            _ligneMenu('Imprimer'),
          ],
        ),
        largeur: 200,
        hauteur: 112,
      ),
    ),
    _etape(4, 'Touchez **Ajouter**, en haut à droite. Le nom proposé est « Tournée » : vous pouvez le garder.'),
    _etape(
      5,
      'L\'icône rouge **Tournée** apparaît sur l\'écran d\'accueil. **Ouvrez toujours l\'application '
      'avec cette icône**, plus jamais par Safari.',
      illustration: _iconeApp(),
    ),
    _encadre(
      'Important sur iPhone',
      'Ce qui est fait dans Safari n\'est pas dans l\'application installée : ce sont deux endroits différents. '
      'Et **ne supprimez pas l\'icône** pendant la tournée.',
    ),
  ],
);

pw.Widget _installerAndroid() => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _titre('Installer l\'application sur Android', numero: '2'),
    _texte('À faire une seule fois, avec le navigateur Chrome (Samsung, Xiaomi, Pixel, etc.).'),
    pw.SizedBox(height: 4),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _etape(1, 'Ouvrez **Chrome** et allez à l\'adresse **$_urlAffichee**. '
                  'Ou visez le QR code de la première page avec l\'appareil photo.'),
              _etape(2, 'Un bandeau jaune apparaît en haut de la carte. Touchez le bouton **Installer**.'),
              _etape(3, 'Chrome demande de confirmer : touchez **Installer** encore une fois.'),
              _etape(4, 'L\'icône rouge **Tournée** apparaît sur l\'écran d\'accueil (ou dans la liste des applications). '
                  'Ouvrez désormais l\'application avec cette icône.'),
              pw.SizedBox(height: 6),
              _encadre(
                'Pas de bouton « Installer » ?',
                'Touchez les **trois petits points** en haut à droite de Chrome, puis '
                '**Installer l\'application** (ou **Ajouter à l\'écran d\'accueil**).',
                couleur: _bleu,
                fond: const PdfColor.fromInt(0xFFE3F2FD),
              ),
              pw.SizedBox(height: 4),
              _telephone(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      color: _fondGris,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: pw.Row(children: [
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(8)),
                            child: pw.Text(_urlAffichee, style: const pw.TextStyle(fontSize: 7.5)),
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        _entoure(_iconeTroisPoints(taille: 14)),
                      ]),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width: 140,
                      child: pw.Column(children: [
                        _ligneMenu('Nouvel onglet'),
                        pw.SizedBox(height: 2),
                        _ligneMenu('Installer l\'application', evidence: true),
                        pw.SizedBox(height: 2),
                        _ligneMenu('Paramètres'),
                      ]),
                    ),
                  ],
                ),
                largeur: 230,
                hauteur: 125,
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 14),
        _capture('01-accueil-installer.jpg', largeur: 175, reperes: const [(222, 101, 2)], legende: 'Le bandeau « Installer » (étape 2)'),
      ],
    ),
  ],
);

pw.Widget _ecranPrincipal() => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _titre('L\'écran principal', numero: '3'),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _capture(
          '03-ma-tournee.jpg',
          largeur: 235,
          reperes: const [(165, 28, 1), (305, 82, 2), (353, 82, 3), (230, 330, 4), (300, 736, 5)],
          legende: 'La carte, sur la tournée n°7',
        ),
        pw.SizedBox(width: 18),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _reperes(const [
                (1, '**Le compteur** : combien de maisons sont faites dans votre tournée, et combien sont à repasser.'),
                (2, '**La loupe** : chercher une adresse (page 8).'),
                (3, '**Le menu** : choisir sa tournée, les listes, la légende des couleurs…'),
                (4, '**Le contour violet** : les limites de votre tournée.'),
                (5, '**Me localiser** : la carte se place sur vous (point bleu). '
                    'La première fois, le téléphone demande l\'autorisation : répondez **Autoriser**.'),
              ]),
              pw.SizedBox(height: 6),
              _encadre(
                'Se déplacer sur la carte',
                'Glissez un doigt pour déplacer la carte. Écartez **deux doigts** pour agrandir : '
                'les maisons apparaissent quand on est assez près.',
                couleur: _bleu,
                fond: const PdfColor.fromInt(0xFFE3F2FD),
              ),
            ],
          ),
        ),
      ],
    ),
  ],
);

pw.Widget _choisirTournee() => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _titre('Choisir sa tournée', numero: '4'),
    _riche('Ouvrez le **menu** (les trois traits en haut à droite), puis touchez **votre tournée**. '
        'La carte se place dessus, entourée de violet. Le choix est gardé : à faire une seule fois.'),
    _riche('Les maisons des autres tournées apparaissent plus pâles, mais **on peut quand même les marquer** '
        'si on les fait.'),
    pw.SizedBox(height: 8),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _capture('02-menu-ma-tournee.jpg', largeur: 195, reperes: const [(362, 712, 1), (292, 135, 2)], legende: 'Menu : « Ma tournée »'),
        _capture('07-toutes-tournees.jpg', largeur: 195, legende: 'Toutes les tournées, avec leur numéro'),
      ],
    ),
    pw.SizedBox(height: 10),
    _reperes(const [
      (1, 'Touchez **votre tournée** (ici la n°7).'),
      (2, '**Afficher toutes les tournées** : voir le découpage de toutes les tournées, chacune avec son numéro.'),
    ]),
  ],
);

pw.Widget _marquerMaison() => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _titre('Marquer une maison', numero: '5'),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _capture('05-panneau.jpg', largeur: 140, legende: 'On touche une maison'),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _recadrage(
                '05-panneau.jpg',
                haut: 588,
                hauteurSource: 186,
                largeur: 300,
                reperes: const [(246, 611, 1), (284, 611, 2), (278, 676, 3), (195, 701, 4)],
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3, bottom: 8),
                child: pw.Text('Le panneau du bas, agrandi', style: pw.TextStyle(fontSize: 10, color: _texteDoux)),
              ),
              _reperes(const [
                (1, '**L\'adresse** de la maison touchée.'),
                (2, '**Itinéraire** pour y aller (page 7).'),
                (3, '**Mémos** : chien, plutôt le soir… (page 7).'),
                (4, '**Touchez le bon bouton**. C\'est enregistré tout de suite, rien d\'autre à faire.'),
              ]),
            ],
          ),
        ),
      ],
    ),
    pw.SizedBox(height: 10),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Les couleurs', style: pw.TextStyle(font: _gras, fontSize: 16, color: _rougeFonce)),
              pw.SizedBox(height: 6),
              for (final (couleur, nom, quand) in [
                (_vert, 'Acheté', 'Ils ont pris un calendrier.'),
                (_orange, 'À repasser', 'Personne n\'a ouvert : il faudra revenir.'),
                (_rouge, 'Refus', 'Ils n\'en veulent pas : ne pas repasser.'),
                (_bleu, 'Non concerné', 'Garage, local vide… Gardé d\'une année sur l\'autre.'),
                (_gris, 'Non visité', 'Pas encore fait (au départ, toutes les maisons).'),
              ])
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 7),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 18,
                        height: 18,
                        decoration: pw.BoxDecoration(color: couleur, borderRadius: pw.BorderRadius.circular(4)),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            style: const pw.TextStyle(fontSize: 12.5),
                            children: [
                              pw.TextSpan(text: '$nom : ', style: pw.TextStyle(font: _gras)),
                              pw.TextSpan(text: quand),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              pw.SizedBox(height: 4),
              _encadre('Une erreur ?', 'Touchez à nouveau la maison et choisissez le bon bouton, '
                  'ou **Remettre en « non visité »**.', couleur: _vert, fond: const PdfColor.fromInt(0xFFE8F5E9)),
            ],
          ),
        ),
        pw.SizedBox(width: 14),
        _capture('04-carte-couleurs.jpg', largeur: 130, legende: 'Les maisons prennent leur couleur (exemple fictif)'),
      ],
    ),
  ],
);

pw.Widget _memosItineraire() => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _titre('Mémos et itinéraire', numero: '6'),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Les mémos', style: pw.TextStyle(font: _gras, fontSize: 16, color: _rougeFonce)),
              pw.SizedBox(height: 6),
              _riche('Dans le panneau d\'une maison, touchez **Mémos**, cochez ce qui est utile, puis **Terminé**.'),
              _riche('Exemples : **Chien**, **Pas de démarchage**, **Mot laissé**, passer **le soir**, '
                  'plutôt **le jeudi**…'),
              _riche('Les mémos s\'affichent sous l\'adresse, pour toute l\'équipe, et sont **gardés d\'une année sur l\'autre**.'),
              pw.SizedBox(height: 6),
              _capture('06-memos.jpg', largeur: 185, legende: 'Les mémos : on coche, c\'est tout'),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('L\'itinéraire', style: pw.TextStyle(font: _gras, fontSize: 16, color: _rougeFonce)),
              pw.SizedBox(height: 6),
              _riche('Touchez le **losange avec une flèche**, à côté de l\'adresse.'),
              _riche('Choisissez votre application de GPS : **Google Maps**, **Waze**, ou **Plans** sur iPhone. '
                  'Elle vous guide jusqu\'à la maison.'),
              pw.SizedBox(height: 6),
              _capture('09-itineraire.jpg', largeur: 185, legende: 'Choix de l\'application de GPS'),
            ],
          ),
        ),
      ],
    ),
  ],
);

pw.Widget _retrouverMaison() => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _titre('Retrouver une maison', numero: '7'),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Les listes', style: pw.TextStyle(font: _gras, fontSize: 16, color: _rougeFonce)),
              pw.SizedBox(height: 6),
              _riche('Menu, puis **À repasser** ou **Non visitées** : la liste des maisons de votre tournée, rue par rue.'),
              _riche('Touchez une maison de la liste : la carte se place dessus.'),
              pw.SizedBox(height: 6),
              _capture('10-listes.jpg', largeur: 185, legende: 'Les maisons non visitées de la tournée'),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('La recherche', style: pw.TextStyle(font: _gras, fontSize: 16, color: _rougeFonce)),
              pw.SizedBox(height: 6),
              _riche('Touchez la **loupe** en haut, puis tapez le début de l\'adresse : un numéro, une rue, une commune. '
                  'Exemple : « 12 prevert ».'),
              _riche('Pas besoin des accents ni des majuscules. Touchez le résultat : la carte se place sur la maison.'),
              pw.SizedBox(height: 6),
              _capture('08-recherche.jpg', largeur: 185, legende: 'Recherche « eglise »'),
            ],
          ),
        ),
      ],
    ),
  ],
);

pw.Widget _bonASavoir() => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _titre('Bon à savoir', numero: '8'),
    _encadre(
      'Sans réseau, ça marche quand même',
      'Dans les coins sans 4G, continuez normalement : tout est gardé dans le téléphone. '
      'Les maisons cochées sont **envoyées toutes seules** aux autres dès que le réseau revient.',
      couleur: _vert,
      fond: const PdfColor.fromInt(0xFFE8F5E9),
    ),
    _encadre(
      'Toute l\'équipe voit la même carte',
      'Une maison marquée par quelqu\'un apparaît chez les autres en moins d\'une minute (avec du réseau). '
      'Si deux personnes marquent la même maison, **la dernière modification compte**.',
      couleur: _bleu,
      fond: const PdfColor.fromInt(0xFFE3F2FD),
    ),
    _encadre(
      'Ne supprimez pas l\'icône',
      'Sur iPhone surtout : supprimer l\'icône efface ce qui n\'a pas encore été envoyé. '
      'Pour une nouvelle version, il suffit de **fermer l\'application et de la rouvrir** avec du réseau.',
    ),
    _encadre(
      'Rien n\'est personnel',
      'L\'application ne garde que l\'adresse, la couleur et les mémos cochés. '
      'Pas de nom, pas de numéro de téléphone, pas de texte libre.',
      couleur: _violet,
      fond: const PdfColor.fromInt(0xFFF3E5F5),
    ),
    pw.SizedBox(height: 10),
    pw.Text('En cas de souci', style: pw.TextStyle(font: _gras, fontSize: 16, color: _rougeFonce)),
    pw.SizedBox(height: 6),
    _texte('• Les maisons n\'apparaissent pas : agrandissez la carte avec deux doigts.'),
    _texte('• Le point bleu ne s\'affiche pas : autorisez la localisation (le téléphone le demande la première fois).'),
    _texte('• L\'application semble ancienne : fermez-la complètement et rouvrez-la avec du réseau.'),
    pw.SizedBox(height: 12),
    pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _gris, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Une question ? Demandez à :', style: pw.TextStyle(font: _gras, fontSize: 13)),
                pw.SizedBox(height: 22),
                pw.Container(height: 1, color: _gris),
              ],
            ),
          ),
          pw.SizedBox(width: 18),
          pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: _url, width: 70, height: 70),
        ],
      ),
    ),
  ],
);
