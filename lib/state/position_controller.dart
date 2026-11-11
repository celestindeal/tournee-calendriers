import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' show LocationServiceDisabledException, PermissionDeniedException;
import 'package:latlong2/latlong.dart';

import '../journal.dart';

/// Une position GPS et sa précision (rayon en mètres).
class PositionGps {
  const PositionGps(this.point, this.precisionM);

  final LatLng point;
  final double precisionM;
}

enum EtatGps {
  /// Pas demandé (la position n'est jamais demandée au démarrage, ARCHITECTURE §7.6).
  arrete,

  /// Demandé, en attente de la première position.
  recherche,

  /// Position reçue.
  actif,

  /// L'utilisateur (ou les réglages de l'iPhone) refuse la localisation.
  refuse,

  /// Pas de position pour l'instant (signal faible, délai dépassé…).
  indisponible,
}

/// Point bleu « Me localiser » (F6).
class PositionController extends ChangeNotifier {
  PositionController({required this._source});

  final Stream<PositionGps> Function() _source;
  StreamSubscription<PositionGps>? _abonnement;
  EtatGps _etat = EtatGps.arrete;
  PositionGps? _position;
  String? _message;
  bool _enPause = false;

  EtatGps get etat => _etat;

  /// Dernière position connue, ou `null`.
  PositionGps? get position => _position;

  /// Message à afficher une fois (puis appeler [effacerMessage]).
  String? get message => _message;
  void effacerMessage() => _message = null;

  /// Démarre le suivi de la position (sans effet s'il est déjà en marche).
  void demarrer() {
    if (_abonnement != null) return;
    _enPause = false;
    _etat = _position == null ? EtatGps.recherche : EtatGps.actif;
    notifyListeners();
    _abonnement = _source().listen(
      _recu,
      onError: _erreur,
      onDone: () => _abonnement = null,
    );
  }

  void arreter() {
    _couper();
    _enPause = false;
    _etat = EtatGps.arrete;
    _position = null;
    notifyListeners();
  }

  /// App passée en arrière-plan : on coupe le GPS (batterie), on le relancera au retour.
  void mettreEnPause() {
    if (_abonnement == null) return;
    _couper();
    _enPause = true;
  }

  /// Retour au premier plan : relance le GPS s'il était en marche avant.
  void reprendre() {
    if (!_enPause) return;
    _enPause = false;
    demarrer();
  }

  void _recu(PositionGps p) {
    _position = p;
    _etat = EtatGps.actif;
    notifyListeners();
  }

  void _erreur(Object erreur) {
    Journal.instance.ajouter('GPS : $erreur');
    if (erreur is PermissionDeniedException) {
      _couper();
      _position = null;
      _etat = EtatGps.refuse;
      _message = 'Localisation refusée. Pour l\'autoriser : Réglages › Confidentialité et sécurité › '
          'Service de localisation › Sites web Safari.';
    } else if (erreur is LocationServiceDisabledException) {
      _couper();
      _position = null;
      _etat = EtatGps.indisponible;
      _message = 'Le service de localisation de l\'iPhone est désactivé.';
    } else {
      // Signal faible ou délai dépassé : on continue d'écouter.
      if (_position == null) {
        _etat = EtatGps.indisponible;
        _message = 'Position introuvable pour l\'instant. Nouvel essai en cours…';
      }
    }
    notifyListeners();
  }

  void _couper() {
    _abonnement?.cancel();
    _abonnement = null;
  }

  @override
  void dispose() {
    _couper();
    super.dispose();
  }
}
