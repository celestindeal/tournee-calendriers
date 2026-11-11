import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tournee_calendriers/models/parcelle.dart';
import 'package:tournee_calendriers/state/recherche.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';
import 'package:tournee_calendriers/ui/recherche_page.dart';

import '../outils.dart';

Parcelle _p(String id, String? adresse, {String insee = '42234'}) => Parcelle(
      id: id,
      adresse: adresse,
      codeInsee: insee,
      surfaceM2: 100,
      centre: const LatLng(45.5, 4.38),
      contours: const [
        [LatLng(45.5, 4.38), LatLng(45.5001, 4.38), LatLng(45.5, 4.3801)],
      ],
      batiments: const [
        [LatLng(45.5, 4.38), LatLng(45.5001, 4.38), LatLng(45.5, 4.3801)],
      ],
    );

void main() {
  final index = IndexAdresses(
    [
      _p('prevert12', '12 Rue Jacques Prévert'),
      _p('prevert12bis', '12 bis Rue Jacques Prévert'),
      _p('prevert112', '112 Rue Jacques Prévert'),
      _p('eculieu', '8 Place d\'Éculieu, Le Bourg'),
      _p('eglise', '3 Rue de l\'Église', insee: '42097'),
      _p('route', '40 Route de Saint-Étienne', insee: '42097'),
      _p('sans', null),
    ],
    nomCommune: (insee) => {'42234': 'Saint-Héand', '42097': 'La Fouillouse'}[insee],
    ordreCommunes: ['42234', '42097'],
  );

  List<String> ids(String requete) => [for (final p in index.chercher(requete)) p.id];

  group('recherche d\'adresse', () {
    test('sans accents ni majuscules, par début de mot', () {
      expect(ids('PREV'), ['prevert12', 'prevert12bis', 'prevert112']);
      expect(ids('eculieu'), ['eculieu']);
      expect(ids('éGLISE'), ['eglise']);
    });

    test('un numéro est un numéro entier', () {
      expect(ids('12 prevert'), ['prevert12', 'prevert12bis']);
      expect(ids('112'), ['prevert112']);
      expect(ids('1'), isEmpty);
    });

    test('la commune et le lieu-dit comptent, les abréviations aussi', () {
      // Ordre des rues : « Route… » avant « Rue… ».
      expect(ids('fouillouse'), ['route', 'eglise']);
      expect(ids('rue fouillouse'), ['eglise']);
      expect(ids('bourg'), ['eculieu']);
      expect(ids('st heand'), ['eculieu', 'prevert12', 'prevert12bis', 'prevert112']);
      expect(ids('rte st etienne'), ['route']);
    });

    test('rien tapé, ou rien trouvé', () {
      expect(ids(''), isEmpty);
      expect(ids('  , '), isEmpty);
      expect(ids('apollo'), isEmpty);
      expect(index.taille, 6);
    });

    test('mots d\'un texte', () {
      expect(motsDe('8 bis Place d’Éculieu'), ['8', 'bis', 'place', 'd', 'eculieu']);
    });
  });

  group('page de recherche', () {
    late TourneeController controller;

    setUp(() async {
      (controller, _, _) = await controleurDeTest(horloge: () => DateTime.utc(2026, 11, 15, 9));
    });

    testWidgets('taper une adresse puis la toucher la renvoie', (tester) async {
      String? choisie;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  choisie = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => RecherchePage(controller: controller)),
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tapez le début'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('champ-recherche')), 'xyz');
      await tester.pump();
      expect(find.text('Aucune adresse trouvée.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('champ-recherche')), '7 prévert');
      await tester.pump();
      expect(find.text('1 adresse'), findsOneWidget);
      expect(find.text('Non visité · Saint-Héand'), findsOneWidget);

      await tester.tap(find.text('7 Rue Jacques Prévert'));
      await tester.pumpAndSettle();
      expect(choisie, 'a');
    });
  });
}
