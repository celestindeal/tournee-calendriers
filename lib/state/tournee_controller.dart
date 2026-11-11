import 'package:flutter/foundation.dart';

import '../data/tournee_repository.dart';
import '../models/avancement.dart';
import '../models/batiment.dart';
import '../models/campagne.dart';
import '../models/etat_batiment.dart';
import '../models/jeu_batiments.dart';
import '../models/statut.dart';

/// État de la tournée affiché par l'interface (docs/ARCHITECTURE.md §5.1).
///
/// Chaque changement met d'abord l'écran à jour (instantané), puis est écrit
/// dans la base. Si l'écriture échoue, l'ancien statut est remis et
/// [derniereErreur] est renseignée.
class TourneeController extends ChangeNotifier {
  TourneeController({
    required this._repo,
    required this.jeu,
    DateTime Function()? horloge,
  })  : _horloge = horloge ?? DateTime.now,
        _parId = {for (final b in jeu.batiments) b.id: b};

  final TourneeRepository _repo;
  final DateTime Function() _horloge;
  final Map<String, Batiment> _parId;

  /// Les bâtiments de la commune (lecture seule).
  final JeuBatiments jeu;

  /// États enregistrés. Peut contenir des ids absents de [jeu] (ancien jeu de
  /// bâtiments) : ils sont conservés mais pas comptés.
  final Map<String, EtatBatiment> _etats = {};

  String? _selectionId;
  Campagne? _campagne;
  String? _derniereErreur;

  Campagne? get campagne => _campagne;

  /// Message à afficher une fois (puis appeler [effacerErreur]).
  String? get derniereErreur => _derniereErreur;

  /// Lit les statuts enregistrés. Crée la campagne au tout premier lancement.
  Future<void> charger() async {
    final etats = await _repo.lireEtats();
    _etats
      ..clear()
      ..addAll(etats);
    _campagne = await _repo.lireCampagne();
    if (_campagne == null) {
      _campagne = Campagne(debut: _horloge().toUtc(), versionBatiments: jeu.version);
      await _repo.enregistrerCampagne(_campagne!);
    }
    notifyListeners();
  }

  Statut statutDe(String batimentId) => _etats[batimentId]?.statut ?? Statut.nonVisite;

  Batiment? batiment(String id) => _parId[id];

  /// Le bâtiment dont le panneau est ouvert, ou `null`.
  Batiment? get selection => _selectionId == null ? null : _parId[_selectionId];

  void selectionner(String? batimentId) {
    final id = batimentId != null && _parId.containsKey(batimentId) ? batimentId : null;
    if (id == _selectionId) return;
    _selectionId = id;
    notifyListeners();
  }

  Avancement get avancement => Avancement.calculer(
        nbBatiments: jeu.batiments.length,
        statuts: [
          for (final e in _etats.entries)
            if (_parId.containsKey(e.key)) e.value.statut,
        ],
      );

  /// Change le statut d'un bâtiment et l'enregistre immédiatement (F2, F3, F4).
  /// Renvoie `false` si l'enregistrement a échoué (l'ancien statut est remis).
  Future<bool> changerStatut(String batimentId, Statut statut) async {
    if (!_parId.containsKey(batimentId)) return false;
    final ancien = _etats[batimentId];
    final nouveau = EtatBatiment(batimentId: batimentId, statut: statut, modifieLe: _horloge().toUtc());
    _appliquer(batimentId, nouveau);
    notifyListeners();
    try {
      await _repo.enregistrer(nouveau);
      return true;
    } catch (e) {
      // Ne pas écraser un changement plus récent fait entre-temps.
      if (identical(_etats[batimentId], nouveau) ||
          (statut == Statut.nonVisite && !_etats.containsKey(batimentId))) {
        _appliquer(batimentId, ancien);
      }
      _derniereErreur = 'Le statut n\'a pas pu être enregistré. Réessayez.';
      debugPrint('Échec d\'enregistrement de $batimentId : $e');
      notifyListeners();
      return false;
    }
  }

  void effacerErreur() => _derniereErreur = null;

  void _appliquer(String batimentId, EtatBatiment? etat) {
    if (etat == null || etat.statut == Statut.nonVisite) {
      _etats.remove(batimentId);
    } else {
      _etats[batimentId] = etat;
    }
  }
}
