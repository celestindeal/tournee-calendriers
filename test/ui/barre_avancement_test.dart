import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/models/filtre.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';
import 'package:tournee_calendriers/ui/barre_avancement.dart';

import '../outils.dart';

void main() {
  late TourneeController controller;

  setUp(() async {
    (controller, _, _) = await controleurDeTest();
  });

  testWidgets('affiche le compteur et se met à jour', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BarreAvancement(controller: controller))));
    expect(find.text('0 / 3 faits (0 %)'), findsOneWidget);
    expect(find.text('0 à repasser'), findsOneWidget);
    expect(find.byKey(const Key('badge-test')), findsNothing);

    await tester.runAsync(() async {
      await controller.changerStatut('a', Statut.achete);
      await controller.changerStatut('b', Statut.aRepasser);
    });
    await tester.pump();
    expect(find.text('1 / 3 faits (33 %)'), findsOneWidget);
    expect(find.text('1 à repasser'), findsOneWidget);
  });

  testWidgets('tient sur une ligne à la largeur d\'un iPhone, badge TEST compris', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: BarreAvancement(controller: controller, onMenu: () {}, onRecherche: () {}, estTest: true),
        ),
      ),
    ));
    expect(find.byKey(const Key('badge-test')), findsOneWidget);
    expect(tester.getSize(find.byType(BarreAvancement)).height, lessThan(70));
    expect(tester.takeException(), isNull);
  });

  testWidgets('l\'étiquette du filtre apparaît et l\'enlève', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: IndicateurFiltre(controller: controller))));
    expect(find.byKey(const Key('filtre-actif')), findsNothing);

    controller.changerFiltre(Filtre.aRepasser);
    await tester.pump();
    expect(find.text('Seulement : à repasser'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filtre-actif')));
    await tester.pump();
    expect(controller.filtre, Filtre.toutes);
    expect(find.byKey(const Key('filtre-actif')), findsNothing);
  });

  testWidgets('la légende montre toutes les couleurs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LegendeCouleurs())));
    for (final s in Statut.values) {
      expect(find.text(s.libelle), findsOneWidget);
    }
  });
}
