import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/models/filtre.dart';
import 'package:tournee_calendriers/models/memo.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';
import 'package:tournee_calendriers/ui/menu_page.dart';
import 'package:tournee_calendriers/ui/listes_page.dart';
import 'package:tournee_calendriers/ui/nouvelle_campagne_page.dart';
import 'package:tournee_calendriers/ui/panneau_statut.dart';

import '../outils.dart';

void main() {
  late TourneeController controller;

  setUp(() async {
    (controller, _, _) = await controleurDeTest(horloge: () => DateTime.utc(2026, 11, 15, 9));
  });

  /// Les écritures dans la base (lancées par un toucher) se terminent.
  Future<void> laisserFinir(WidgetTester tester) => tester.pump(const Duration(seconds: 1));

  group('mémos dans le panneau', () {
    testWidgets('cocher « Chien » et « Jeudi », puis les voir sous l\'adresse', (tester) async {
      controller.selectionner('a');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Align(
              alignment: Alignment.bottomCenter,
              child: PanneauStatut(controller: controller, parcelle: controller.parcelle('a')!),
            ),
          ),
        ),
      ));
      expect(find.text('Aucun mémo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bouton-memos')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memo-chien')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('memo-jeudi')));
      await laisserFinir(tester);
      expect(controller.memosDe('a'), {Memo.chien, Memo.jeudi});

      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();
      expect(find.text('Chien'), findsOneWidget);
      expect(find.text('Jeu'), findsOneWidget);
      expect(find.text('Aucun mémo'), findsNothing);
    });
  });

  group('menu', () {
    Future<void> ouvrirMenu(WidgetTester tester, void Function(String?) retour) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => retour(await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => MenuPage(controller: controller, plateforme: PlateformeDeTest())),
                )),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('choisir le filtre « À repasser » revient sur la carte', (tester) async {
      await ouvrirMenu(tester, (_) {});
      expect(find.byKey(const Key('legende')), findsOneWidget);
      await tester.tap(find.byKey(const Key('filtre-aRepasser')));
      await tester.pumpAndSettle();
      expect(controller.filtre, Filtre.aRepasser);
      expect(find.text('ouvrir'), findsOneWidget);
    });

    testWidgets('une maison choisie dans une liste du menu est renvoyée à la carte', (tester) async {
      await tester.runAsync(() => controller.changerStatut('a', Statut.aRepasser));
      String? choisie;
      await ouvrirMenu(tester, (id) => choisie = id);
      expect(find.text('À repasser (1)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-a-repasser')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 Rue Jacques Prévert'));
      await tester.pumpAndSettle();
      expect(choisie, 'a');
      expect(find.text('ouvrir'), findsOneWidget);
    });
  });

  group('listes', () {
    testWidgets('onglets, communes, et toucher une maison la renvoie', (tester) async {
      await tester.runAsync(() async {
        await controller.changerStatut('a', Statut.aRepasser);
        await controller.basculerMemo('a', Memo.soir);
        await controller.changerStatut('b', Statut.achete);
      });
      String? choisie;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  choisie = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => ListesPage(controller: controller)),
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

      expect(find.text('À repasser (1)'), findsOneWidget);
      expect(find.text('Non visitées (1)'), findsOneWidget);
      expect(find.text('7 Rue Jacques Prévert'), findsOneWidget);
      expect(find.textContaining('À repasser depuis'), findsOneWidget);
      expect(find.text('Le soir'), findsOneWidget);
      expect(find.text('Rue Jacques Prévert · Saint-Héand · 1'), findsOneWidget);

      await tester.tap(find.text('7 Rue Jacques Prévert'));
      await tester.pumpAndSettle();
      expect(choisie, 'a');
    });
  });

  group('nouvelle campagne', () {
    testWidgets('propose l\'année suivante, demande confirmation, remet à zéro', (tester) async {
      await tester.runAsync(() => controller.changerStatut('a', Statut.achete));
      await tester.pumpWidget(MaterialApp(home: NouvelleCampagnePage(controller: controller)));

      final annee = DateTime.now().year > 2026 ? DateTime.now().year : 2027;
      expect(find.text('Campagne $annee'), findsOneWidget);

      await tester.tap(find.byKey(const Key('commencer-campagne')));
      await tester.pumpAndSettle();
      expect(find.textContaining('n\'a pas été exportée'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('confirmer-nouvelle-campagne')));
        // Laisse l'archivage se faire dans la base.
        for (var i = 0; i < 20 && controller.campagne!.annee != annee; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect(controller.campagne!.annee, annee);
      expect(controller.statutDe('a'), Statut.nonVisite);
      expect(controller.statutPrecedent('a'), (annee: 2026, statut: Statut.achete));
    });
  });
}
