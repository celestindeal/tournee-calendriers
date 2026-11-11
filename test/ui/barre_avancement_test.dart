import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';
import 'package:tournee_calendriers/ui/barre_avancement.dart';

import '../outils.dart';

void main() {
  late TourneeController controller;

  setUp(() async {
    (controller, _, _) = await controleurDeTest();
  });

  testWidgets('affiche le compteur et la légende, et se met à jour', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BarreAvancement(controller: controller))));
    expect(find.text('0 / 3 faits (0 %) – 0 à repasser'), findsOneWidget);
    for (final s in Statut.values) {
      expect(find.text(s.libelle), findsOneWidget);
    }

    await tester.runAsync(() async {
      await controller.changerStatut('a', Statut.achete);
      await controller.changerStatut('b', Statut.aRepasser);
    });
    await tester.pump();
    expect(find.text('1 / 3 faits (33 %) – 1 à repasser'), findsOneWidget);
  });
}
