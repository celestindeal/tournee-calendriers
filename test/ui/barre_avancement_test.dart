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

  /// Texte du compteur (« 1 faite · 2 visitées / 3 »).
  String compteur(WidgetTester tester) => tester
      .widget<RichText>(find.descendant(of: find.byKey(const Key('compteur')), matching: find.byType(RichText)))
      .text
      .toPlainText()
      .replaceAll(RegExp(r'\s+'), ' ');

  testWidgets('affiche faites et visitées, et se met à jour', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BarreAvancement(controller: controller))));
    expect(compteur(tester), '0 faite · 0 visitée / 3');
    expect(find.text('0 à repasser'), findsOneWidget);
    expect(find.byKey(const Key('badge-test')), findsNothing);

    await tester.runAsync(() async {
      await controller.changerStatut('a', Statut.achete);
      await controller.changerStatut('b', Statut.aRepasser);
    });
    await tester.pump();
    // Faites = sans les maisons à repasser ; visitées = avec.
    expect(compteur(tester), '1 faite · 2 visitées / 3');
    expect(find.text('1 à repasser'), findsOneWidget);
  });

  testWidgets('barre en deux couleurs : vert puis orange', (tester) async {
    await tester.runAsync(() async {
      await controller.changerStatut('a', Statut.achete);
      await controller.changerStatut('b', Statut.aRepasser);
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 300, child: BarreBicolore(avancement: controller.avancement))),
    ));
    final segments = find.descendant(of: find.byKey(const Key('barre-bicolore')), matching: find.byType(ColoredBox));
    final couleurs = [for (final b in tester.widgetList<ColoredBox>(segments)) b.color];
    expect(couleurs.take(2), [Statut.achete.couleur, Statut.aRepasser.couleur]);
    // Un tiers chacun : vert, orange, gris.
    expect(tester.getSize(segments.first).width, closeTo(100, 1));
  });

  testWidgets('toucher le compteur montre le détail', (tester) async {
    await tester.runAsync(() async {
      await controller.changerStatut('a', Statut.achete);
      await controller.changerStatut('b', Statut.aRepasser);
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BarreAvancement(controller: controller))));
    await tester.tap(find.byKey(const Key('bouton-detail-avancement')));
    await tester.pumpAndSettle();
    expect(find.text('Avancement de toute la carte'), findsOneWidget);
    expect(find.text('1 (33 %)'), findsOneWidget); // faites
    expect(find.text('2 (66 %)'), findsOneWidget); // premier tour
    expect(tester.widget<Text>(find.byKey(const Key('detail-non-visitees'))).data, '1');
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
