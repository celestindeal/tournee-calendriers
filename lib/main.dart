import 'package:flutter/material.dart';
import 'package:sembast_web/sembast_web.dart';

import 'app.dart';
import 'data/batiments_source.dart';
import 'data/tournee_repository.dart';
import 'platform/navigateur.dart';
import 'state/tournee_controller.dart';

void main() {
  runApp(TourneeApp(
    demarrer: _demarrer,
    conseilInstallation: !estAppInstallee(),
  ));
}

Future<TourneeController> _demarrer() async {
  // Sans attendre : la réponse ne bloque pas le démarrage.
  demanderStockagePersistant();

  final jeu = await BatimentsSource().charger();
  // IndexedDB du navigateur (sur l'iPhone : propre à l'app de l'écran d'accueil).
  final repo = await TourneeRepository.ouvrir(databaseFactoryWeb);
  final controller = TourneeController(repo: repo, jeu: jeu);
  await controller.charger();
  return controller;
}
