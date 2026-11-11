import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';
import 'package:tournee_calendriers/ui/itineraire.dart';
import 'package:tournee_calendriers/ui/panneau_statut.dart';

import '../outils.dart';

void main() {
  const maison = LatLng(45.5141972, 4.3796581);

  group('liens d\'itinéraire', () {
    test('Plans (Apple)', () {
      expect(
        AppliNavigation.plans.lien(maison).toString(),
        'https://maps.apple.com/?daddr=45.514197%2C4.379658&dirflg=d',
      );
    });

    test('Google Maps', () {
      expect(
        AppliNavigation.googleMaps.lien(maison).toString(),
        'https://www.google.com/maps/dir/?api=1&destination=45.514197%2C4.379658&travelmode=driving',
      );
    });

    test('Waze', () {
      expect(
        AppliNavigation.waze.lien(maison).toString(),
        'https://waze.com/ul?ll=45.514197%2C4.379658&navigate=yes',
      );
    });
  });

  group('dans le panneau', () {
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

    testWidgets('l\'icône à côté de l\'adresse propose Plans, Google Maps et Waze', (tester) async {
      await afficher(tester, 'a');
      expect(find.byKey(const Key('bouton-itineraire')), findsOneWidget);

      await tester.tap(find.byKey(const Key('bouton-itineraire')));
      await tester.pumpAndSettle();

      expect(find.text('Itinéraire vers 7 Rue Jacques Prévert'), findsOneWidget);
      for (final a in AppliNavigation.values) {
        expect(find.byKey(Key('itineraire-${a.name}')), findsOneWidget);
      }
    });

    testWidgets('aussi sans adresse connue', (tester) async {
      await afficher(tester, 'c');
      await tester.tap(find.byKey(const Key('bouton-itineraire')));
      await tester.pumpAndSettle();
      expect(find.text('Itinéraire'), findsOneWidget);
    });
  });
}
