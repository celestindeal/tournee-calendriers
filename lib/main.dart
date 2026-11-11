import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sembast_web/sembast_web.dart';

import 'app.dart';
import 'config.dart';
import 'data/batiments_source.dart';
import 'data/tournee_repository.dart';
import 'journal.dart';
import 'platform/gps.dart';
import 'platform/navigateur.dart';
import 'state/position_controller.dart';
import 'state/tournee_controller.dart';

void main() {
  // Toutes les erreurs vont dans le journal de la page Diagnostic.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Journal.instance.ajouter(details.exceptionAsString(), details.stack);
  };
  PlatformDispatcher.instance.onError = (erreur, pile) {
    Journal.instance.ajouter(erreur, pile);
    return false;
  };

  runApp(TourneeApp(
    demarrer: _demarrer,
    plateforme: PlateformeNavigateur(),
    position: PositionController(source: fluxGeolocator),
  ));
}

Future<TourneeController> _demarrer() async {
  // Sans attendre : la réponse ne bloque pas le démarrage.
  demanderStockagePersistant();

  final jeu = await BatimentsSource().charger();
  // IndexedDB du navigateur (sur l'iPhone : propre à l'app de l'écran d'accueil).
  // Base séparée pour l'environnement de test (voir config.dart).
  final repo = await TourneeRepository.ouvrir(databaseFactoryWeb, nom: nomBase);
  final controller = TourneeController(repo: repo, jeu: jeu);
  await controller.charger();
  return controller;
}
