import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tournee_calendriers/data/tournee_repository.dart';
import 'package:tournee_calendriers/models/jeu_parcelles.dart';
import 'package:tournee_calendriers/models/secteur.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';
import 'package:tournee_calendriers/ui/listes_page.dart';
import 'package:tournee_calendriers/ui/panneau_statut.dart';

import '../../tool/preparer_tournees.dart' show lireKml;
import '../outils.dart';

/// Carré autour d'un point (les parcelles de test sont à 4.38 de longitude).
List<LatLng> _carre(double lat) => [
  LatLng(lat - 0.005, 4.37),
  LatLng(lat - 0.005, 4.39),
  LatLng(lat + 0.005, 4.39),
  LatLng(lat + 0.005, 4.37),
];

/// Tournée 7 autour de « a », tournée 3 autour de « b » ; « c » hors tournées.
final _secteurs = [
  Secteur(numero: 3, nom: 'Tournée n°3', contours: [_carre(45.52)]),
  Secteur(numero: 7, nom: 'Tournée n°7', contours: [_carre(45.51)]),
];

void main() {
  group('contour d\'une tournée', () {
    test('un point dedans, un point dehors, l\'emprise', () {
      final t = _secteurs[1];
      expect(t.contient(const LatLng(45.51, 4.38)), isTrue);
      expect(t.contient(const LatLng(45.52, 4.38)), isFalse);
      expect(t.emprise.sudOuest.latitude, closeTo(45.505, 1e-9));
      expect(t.emprise.sudOuest.longitude, closeTo(4.37, 1e-9));
      expect(t.emprise.nordEst.latitude, closeTo(45.515, 1e-9));
      expect(t.emprise.nordEst.longitude, closeTo(4.39, 1e-9));
    });

    test('lecture du KML de Google My Maps', () {
      const kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml><Document><name>Tournées</name>
<Placemark><name>Tournée n°7</name><Polygon><outerBoundaryIs><LinearRing><coordinates>
  4.36,45.53,0 4.37,45.53,0 4.37,45.54,0 4.36,45.53,0
</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark>
<Placemark><name>Caserne</name><Point><coordinates>4.36,45.53,0</coordinates></Point></Placemark>
<Placemark><name><![CDATA[T12 & co]]></name><LineString><coordinates>4.1,45.1 4.2,45.1 4.2,45.2</coordinates></LineString></Placemark>
</Document></kml>''';
      final formes = lireKml(kml);
      expect([for (final f in formes) f.numero], [7, 12]);
      expect(formes.first.points.first, (45.53, 4.36));
      expect(formes.last.nom, 'T12 & co');
    });

    test('le vrai fichier des tournées : la tournée 7 contient des maisons de Saint-Héand', () {
      final secteurs = Secteur.listeDepuisJson(
        jsonDecode(File('assets/data/tournees.json').readAsStringSync()) as Map<String, dynamic>,
      );
      final t7 = secteurs.firstWhere((s) => s.numero == 7);
      final jeu = JeuParcelles.depuisJson(
        jsonDecode(File('assets/data/parcelles.json').readAsStringSync()) as Map<String, dynamic>,
      );
      // Nombre de maisons par tournée, et maisons comptées dans deux tournées
      // (contours qui se chevauchent : la tournée au plus petit numéro l'emporte dans l'app).
      for (final s in secteurs) {
        final n = jeu.parcelles.where((p) => s.contient(p.centre)).length;
        // ignore: avoid_print
        print('${s.nom} : $n maisons');
      }
      final enDouble = jeu.parcelles.where((p) => secteurs.where((s) => s.contient(p.centre)).length > 1).toList();
      // ignore: avoid_print
      print('Maisons dans deux tournées : ${enDouble.length} ${[for (final p in enDouble.take(10)) '${p.adresse ?? p.id} (tournées ${[for (final s in secteurs) if (s.contient(p.centre)) s.numero].join(' et ')})']}');
      final dedans = jeu.parcelles.where((p) => t7.contient(p.centre)).toList();
      expect(dedans.length, greaterThan(100));
      expect(dedans.length, lessThan(jeu.parcelles.length ~/ 2));
    });
  });

  group('ma tournée', () {
    late TourneeRepository repo;
    late TourneeController controller;

    Future<TourneeController> ouvrir() async {
      final c = TourneeController(repo: repo, jeu: jeuDeTest(), secteurs: _secteurs);
      await c.charger();
      return c;
    }

    setUp(() async {
      repo = await TourneeRepository.ouvrir(newDatabaseFactoryMemory());
      controller = await ouvrir();
    });

    test('sans tournée choisie : toute la carte', () {
      expect(controller.maTournee, isNull);
      expect(controller.estDansMaTournee('c'), isTrue);
      expect(controller.tourneeDe('a'), 7);
      expect(controller.tourneeDe('b'), 3);
      expect(controller.tourneeDe('c'), isNull);
      expect(controller.avancement.total, 3);
    });

    test('le compteur porte sur ma tournée, le choix est gardé sur le téléphone', () async {
      await controller.changerStatut('a', Statut.achete);
      await controller.changerStatut('b', Statut.aRepasser);
      await controller.choisirMaTournee(_secteurs[1]);

      expect(controller.estDansMaTournee('a'), isTrue);
      expect(controller.estDansMaTournee('b'), isFalse);
      expect(controller.nbMaisonsDe(_secteurs[1]), 1);
      expect(controller.avancement.total, 1);
      expect(controller.avancement.faits, 1);
      expect(controller.avancement.aRepasser, 0);

      // On peut toujours modifier une maison d'une autre tournée.
      expect(await controller.changerStatut('c', Statut.refus), isTrue);

      final rouvert = await ouvrir();
      expect(rouvert.maTournee?.numero, 7);

      await rouvert.choisirMaTournee(null);
      expect((await ouvrir()).maTournee, isNull);
    });

    testWidgets('le panneau signale une maison hors de ma tournée', (tester) async {
      await tester.runAsync(() => controller.choisirMaTournee(_secteurs[1]));
      Future<void> afficher(String id) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: PanneauStatut(controller: controller, parcelle: controller.parcelle(id)!),
              ),
            ),
          ));
      await afficher('a');
      expect(find.byKey(const Key('hors-tournee')), findsNothing);
      await afficher('b');
      expect(find.text('Hors de ta tournée (tournée n°3)'), findsOneWidget);
      await afficher('c');
      expect(find.text('Hors de ta tournée'), findsOneWidget);
    });

    testWidgets('les listes montrent ma tournée par défaut', (tester) async {
      await tester.runAsync(() => controller.choisirMaTournee(_secteurs[1]));
      await tester.pumpWidget(MaterialApp(home: ListesPage(controller: controller, ongletInitial: 1)));
      expect(find.text('Non visitées (1)'), findsOneWidget);
      expect(find.text('Tournée n°7'), findsOneWidget);

      await tester.tap(find.byKey(const Key('commune-toutes')));
      await tester.pump();
      expect(find.text('Non visitées (3)'), findsOneWidget);
    });
  });
}
