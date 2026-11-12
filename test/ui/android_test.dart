import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tournee_calendriers/platform/systeme.dart';
import 'package:tournee_calendriers/ui/conseil_installation.dart';
import 'package:tournee_calendriers/ui/itineraire.dart';

import '../outils.dart';

void main() {
  tearDown(() => systemeCourant = Systeme.autre);

  group('système du téléphone', () {
    test('reconnu dans le user agent', () {
      expect(
        Systeme.detecter('Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/131.0 Mobile Safari/537.36'),
        Systeme.android,
      );
      expect(
        Systeme.detecter('Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148'),
        Systeme.ios,
      );
      expect(
        Systeme.detecter('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'),
        Systeme.ios,
      );
      expect(Systeme.detecter('Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/131.0 Safari/537.36'), Systeme.autre);
    });
  });

  group('itinéraire', () {
    test('pas de Plans d\'Apple sur Android', () {
      expect(AppliNavigation.pour(Systeme.android), [AppliNavigation.googleMaps, AppliNavigation.waze]);
      expect(AppliNavigation.pour(Systeme.ios), AppliNavigation.values);
    });

    testWidgets('le menu d\'itinéraire suit le système', (tester) async {
      systemeCourant = Systeme.android;
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: BoutonItineraire(destination: LatLng(45.5, 4.38)))),
      ));
      await tester.tap(find.byKey(const Key('bouton-itineraire')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('itineraire-plans')), findsNothing);
      expect(find.byKey(const Key('itineraire-googleMaps')), findsOneWidget);
      expect(find.byKey(const Key('itineraire-waze')), findsOneWidget);
    });
  });

  group('conseil d\'installation', () {
    Future<void> afficher(WidgetTester tester, Systeme systeme, {VoidCallback? onInstaller}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConseilInstallation(systeme: systeme, onFermer: () {}, onInstaller: onInstaller),
        ),
      ),
    );

    testWidgets('iPhone : Safari, Partager', (tester) async {
      await afficher(tester, Systeme.ios);
      expect(find.textContaining('Partager'), findsOneWidget);
      expect(find.byKey(const Key('bouton-installer')), findsNothing);
    });

    testWidgets('Android sans invitation : menu de Chrome', (tester) async {
      await afficher(tester, Systeme.android);
      expect(find.textContaining('menu ⋮ de Chrome'), findsOneWidget);
      expect(find.byKey(const Key('bouton-installer')), findsNothing);
    });

    testWidgets('Android avec invitation : bouton « Installer »', (tester) async {
      final plateforme = PlateformeDeTest(estAppInstallee: false)..recevoirInvitation();
      var installe = false;
      await afficher(
        tester,
        Systeme.android,
        onInstaller: () async => installe = await plateforme.installer(),
      );
      await tester.tap(find.byKey(const Key('bouton-installer')));
      await tester.pump();
      expect(installe, isTrue);
      expect(plateforme.nbInstallations, 1);
      expect(plateforme.peutInstaller, isFalse);
    });
  });
}
