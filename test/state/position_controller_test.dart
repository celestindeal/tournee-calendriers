import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show PermissionDeniedException;
import 'package:latlong2/latlong.dart';
import 'package:tournee_calendriers/platform/systeme.dart';
import 'package:tournee_calendriers/state/position_controller.dart';

void main() {
  late StreamController<PositionGps> flux;
  late int abonnements;
  late PositionController gps;

  setUp(() {
    abonnements = 0;
    flux = StreamController<PositionGps>.broadcast(onListen: () => abonnements++);
    gps = PositionController(source: () => flux.stream);
  });

  tearDown(() => flux.close());

  const ici = PositionGps(LatLng(45.53, 4.38), 12);

  test('rien n\'est demandé tant qu\'on n\'appuie pas sur « Me localiser »', () {
    expect(gps.etat, EtatGps.arrete);
    expect(abonnements, 0);
  });

  test('recherche puis position reçue', () async {
    gps.demarrer();
    expect(gps.etat, EtatGps.recherche);
    flux.add(ici);
    await pumpEventQueue();
    expect(gps.etat, EtatGps.actif);
    expect(gps.position!.precisionM, 12);
  });

  test('démarrer deux fois n\'ouvre qu\'un seul suivi', () {
    gps
      ..demarrer()
      ..demarrer();
    expect(abonnements, 1);
  });

  test('refus : arrêt du suivi et message expliquant les Réglages (iPhone)', () async {
    systemeCourant = Systeme.ios;
    addTearDown(() => systemeCourant = Systeme.autre);
    gps.demarrer();
    flux.addError(const PermissionDeniedException('refusé'));
    await pumpEventQueue();
    expect(gps.etat, EtatGps.refuse);
    expect(gps.message, contains('Réglages'));
    expect(flux.hasListener, isFalse);
    gps.effacerMessage();
    expect(gps.message, isNull);
  });

  test('signal faible : on garde la dernière position et on continue d\'écouter', () async {
    gps.demarrer();
    flux.add(ici);
    await pumpEventQueue();
    flux.addError(TimeoutException('délai'));
    await pumpEventQueue();
    expect(gps.etat, EtatGps.actif);
    expect(gps.position, isNotNull);
    expect(flux.hasListener, isTrue);
  });

  test('signal faible sans aucune position : indisponible, nouvel essai', () async {
    gps.demarrer();
    flux.addError(TimeoutException('délai'));
    await pumpEventQueue();
    expect(gps.etat, EtatGps.indisponible);
    expect(flux.hasListener, isTrue);
  });

  test('arrière-plan : pause puis reprise au retour', () async {
    gps.demarrer();
    gps.mettreEnPause();
    expect(flux.hasListener, isFalse);
    gps.reprendre();
    expect(flux.hasListener, isTrue);
    expect(abonnements, 2);
  });

  test('pas de reprise si le GPS n\'était pas en marche', () {
    gps
      ..mettreEnPause()
      ..reprendre();
    expect(abonnements, 0);
  });

  test('arrêter efface la position', () async {
    gps.demarrer();
    flux.add(ici);
    await pumpEventQueue();
    gps.arreter();
    expect(gps.etat, EtatGps.arrete);
    expect(gps.position, isNull);
    expect(flux.hasListener, isFalse);
  });
}
