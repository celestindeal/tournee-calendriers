import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/journal.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';
import 'package:tournee_calendriers/ui/diagnostic_page.dart';
import 'package:tournee_calendriers/ui/menu_page.dart';

import '../outils.dart';

void main() {
  late TourneeController controller;

  setUp(() async {
    Journal.instance.vider();
    (controller, _, _) = await controleurDeTest();
  });

  group('Menu', () {
    // Écran haut : tout le menu est construit, sans faire défiler.
    Future<void> afficher(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(MaterialApp(
        home: MenuPage(controller: controller, plateforme: PlateformeDeTest()),
      ));
    }

    testWidgets('propose export et import, pas d\'annulation sans import', (tester) async {
      await afficher(tester);
      expect(find.text('Exporter la tournée'), findsOneWidget);
      expect(find.text('Jamais exportée'), findsOneWidget);
      expect(find.text('Importer une sauvegarde'), findsOneWidget);
      expect(find.byKey(const Key('menu-annuler-import')), findsNothing);
    });

    testWidgets('signale en rouge une tournée jamais exportée', (tester) async {
      await tester.runAsync(() => controller.changerStatut('a', Statut.achete));
      await afficher(tester);
      final texte = tester.widget<Text>(find.text('Jamais exportée'));
      expect(texte.style?.color, Theme.of(tester.element(find.text('Jamais exportée'))).colorScheme.error);
    });

    testWidgets('« Annuler le dernier import » apparaît après un import', (tester) async {
      await tester.runAsync(() => controller.importer(controller.lireImport(controller.contenuExport(DateTime.now()))));
      await afficher(tester);
      expect(find.byKey(const Key('menu-annuler-import')), findsOneWidget);
    });
  });

  group('Diagnostic', () {
    testWidgets('affiche l\'état de l\'app et les erreurs récentes', (tester) async {
      Journal.instance.ajouter('Erreur de test');
      await tester.pumpWidget(MaterialApp(
        home: DiagnosticPage(controller: controller, plateforme: PlateformeDeTest(estAppInstallee: false)),
      ));
      await tester.pump(); // fin du chargement des informations

      expect(find.text('3 parcelles, version test-1\nSaint-Héand'), findsOneWidget);
      expect(find.text('non (onglet du navigateur)'), findsOneWidget);
      expect(find.text('actif · app-test : 27'), findsOneWidget);
      // Le bas de la liste n'est construit qu'une fois visible.
      await tester.scrollUntilVisible(
        find.byKey(const Key('diagnostic-copier')),
        200,
        scrollable: find.byType(Scrollable).first, // la liste (les textes sélectionnables défilent aussi)
      );
      expect(find.textContaining('Erreur de test'), findsOneWidget);
      expect(find.byKey(const Key('diagnostic-copier')), findsOneWidget);
    });
  });
}
