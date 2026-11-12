import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'plateforme.dart';

// Fonctions propres au navigateur (ARCHITECTURE §7.5).
// Importé uniquement par main.dart : les tests (sur le PC, hors navigateur)
// n'en dépendent pas.

class PlateformeNavigateur implements Plateforme {
  @override
  bool get estAppInstallee => estAppInstalleeDansNavigateur();

  @override
  String get navigateur {
    try {
      return web.window.navigator.userAgent;
    } catch (_) {
      return 'inconnu';
    }
  }

  @override
  bool get peutInstaller => InstallationNavigateur.peutInstaller();

  @override
  Future<bool> installer() => InstallationNavigateur.installer();

  @override
  void surChangementInstallation(void Function() rappel) {
    try {
      web.window.addEventListener('invitation-installation', ((web.Event _) => rappel()).toJS);
    } catch (_) {}
  }

  @override
  Future<bool> stockagePersistant() async {
    try {
      return (await web.window.navigator.storage.persisted().toDart).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> serviceWorker() async {
    try {
      final enregistrement = await web.window.navigator.serviceWorker.getRegistration().toDart;
      final actif = enregistrement?.active;
      if (actif == null) return 'aucun (hors-ligne indisponible)';
      final morceaux = <String>['actif'];
      final caches = web.window.caches;
      for (final nom in (await caches.keys().toDart).toDart) {
        final cache = await caches.open(nom.toDart).toDart;
        final nb = (await cache.keys().toDart).toDart.length;
        morceaux.add('${nom.toDart} : $nb');
      }
      return morceaux.join(' · ');
    } catch (e) {
      return 'inconnu ($e)';
    }
  }
}

/// Invitation à installer l'app gardée par web/index.html (Chrome, Android).
extension type _Invitation(JSObject _) implements JSObject {
  external JSPromise<JSAny?> prompt();
  external JSPromise<_Choix> get userChoice;
}

extension type _Choix(JSObject _) implements JSObject {
  external String get outcome;
}

@JS('invitationInstallation')
external _Invitation? get _invitation;

@JS('invitationInstallation')
external set _invitation(_Invitation? valeur);

extension InstallationNavigateur on PlateformeNavigateur {
  static bool peutInstaller() {
    try {
      return _invitation != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> installer() async {
    final invitation = _invitation;
    if (invitation == null) return false;
    try {
      await invitation.prompt().toDart;
      final choix = await invitation.userChoice.toDart;
      // Une invitation ne sert qu'une fois.
      _invitation = null;
      return choix.outcome == 'accepted';
    } catch (_) {
      return false;
    }
  }
}

/// Vrai si l'app est ouverte depuis l'icône de l'écran d'accueil (et non dans
/// un onglet Safari, qui a un stockage SÉPARÉ et peut être effacé par iOS).
bool estAppInstalleeDansNavigateur() {
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
