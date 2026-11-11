import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// Fonctions propres au navigateur (ARCHITECTURE §7.5).
// Importé uniquement par main.dart : les tests (sur le PC, hors navigateur)
// n'en dépendent pas.

/// Vrai si l'app est ouverte depuis l'icône de l'écran d'accueil (et non dans
/// un onglet Safari, qui a un stockage SÉPARÉ et peut être effacé par iOS).
bool estAppInstallee() {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches ||
        (web.window.navigator._standalone?.toDart ?? false);
  } catch (_) {
    return false;
  }
}

/// Demande au navigateur de ne pas effacer les données de l'app quand il
/// manque de place. Renvoie vrai si c'est accordé.
Future<bool> demanderStockagePersistant() async {
  try {
    final stockage = web.window.navigator.storage;
    if ((await stockage.persisted().toDart).toDart) return true;
    final accorde = (await stockage.persist().toDart).toDart;
    debugPrint('Stockage persistant : ${accorde ? 'accordé' : 'refusé'}');
    return accorde;
  } catch (e) {
    debugPrint('Stockage persistant indisponible : $e');
    return false;
  }
}

extension on web.Navigator {
  /// Propriété propre à Safari iOS : vrai dans une app de l'écran d'accueil.
  @JS('standalone')
  external JSBoolean? get _standalone;
}
