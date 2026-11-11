import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sembast_web/sembast_web.dart';

import 'app.dart';
import 'config.dart';
import 'data/parcelles_source.dart';
import 'data/tournee_repository.dart';
import 'journal.dart';
import 'platform/gps.dart';
import 'platform/navigateur.dart';
import 'state/position_controller.dart';
import 'state/tournee_controller.dart';
import 'synchro/serveur_synchro.dart';
import 'synchro/synchro_controller.dart';

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

  runApp(
    TourneeApp(
      demarrer: _demarrer,
      plateforme: PlateformeNavigateur(),
      position: PositionController(source: fluxGeolocator),
    ),
  );
}

Future<TourneeController> _demarrer() async {
  // Sans attendre : la réponse ne bloque pas le démarrage.
  demanderStockagePersistant();

  final jeu = await ParcellesSource().charger();
  // IndexedDB du navigateur (sur l'iPhone : propre à l'app de l'écran d'accueil).
  // Base séparée pour l'environnement de test (voir config.dart).
  final repo = await TourneeRepository.ouvrir(databaseFactoryWeb, nom: nomBase);
  final controller = TourneeController(repo: repo, jeu: jeu);
  await controller.charger();
  // Synchronisation entre téléphones (si une adresse de serveur est réglée).
  // Tables séparées pour l'environnement de test.
  final synchro = SynchroController(
    repo: repo,
    tournee: controller,
    fabriqueServeur: (c) => ServeurPocketBase(
      adresse: c.adresse,
      code: c.code,
      prefixeTables: estProduction ? '' : 'test_',
      appareil: c.appareil,
    ),
  );
  await synchro.charger();
  return controller;
}
