import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';
import 'package:tournee_calendriers/ui/panneau_statut.dart';

import '../outils.dart';

/// Les tests de widgets simulent le temps : on le fait avancer pour que
/// l'écriture dans la base (lancée par l'appui) se termine avant la fin du test.
Future<void> _laisserFinirEcriture(WidgetTester tester) => tester.pump(const Duration(seconds: 1));

void main() {
  late TourneeController controller;

  setUp(() async {
    (controller, _, _) = await controleurDeTest();
  });

  Future<void> afficher(WidgetTester tester, String id) async {
    controller.selectionner(id);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: PanneauStatut(controller: controller, parcelle: controller.selection!),
        ),
      ),
    ));
  }

  testWidgets('affiche l\'adresse et les 4 boutons de statut', (tester) async {
    await afficher(tester, 'a');
    expect(find.text('7 Rue Jacques Prévert'), findsOneWidget);
    for (final s in [Statut.achete, Statut.aRepasser, Statut.refus, Statut.nonConcerne]) {
      expect(find.byKey(Key('bouton-${s.name}')), findsOneWidget);
    }
    // Pas de « remettre en non visité » pour un bâtiment encore non visité.
    expect(find.byKey(const Key('bouton-nonVisite')), findsNothing);
  });

  testWidgets('« Adresse inconnue » quand le bâtiment n\'a pas d\'adresse', (tester) async {
    await afficher(tester, 'c');
    expect(find.text('Adresse inconnue'), findsOneWidget);
  });

  testWidgets('choisir un statut l\'applique et ferme le panneau', (tester) async {
    await afficher(tester, 'b');
    await tester.tap(find.byKey(const Key('bouton-aRepasser')));
    expect(controller.statutDe('b'), Statut.aRepasser);
    expect(controller.selection, isNull);
    await _laisserFinirEcriture(tester);
  });

  testWidgets('le statut actuel est coché et peut être remis à « non visité »', (tester) async {
    await tester.runAsync(() => controller.changerStatut('a', Statut.refus));
    await afficher(tester, 'a');
    expect(find.text('Fait – refus · Saint-Héand · terrain de 944 m²'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('bouton-refus')), matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('bouton-nonVisite')));
    expect(controller.statutDe('a'), Statut.nonVisite);
    await _laisserFinirEcriture(tester);
  });

  testWidgets('les boutons font au moins 56 px de haut (usage au pouce)', (tester) async {
    await afficher(tester, 'a');
    expect(tester.getSize(find.byKey(const Key('bouton-achete'))).height, greaterThanOrEqualTo(56));
  });
}
