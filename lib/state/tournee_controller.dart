import 'package:flutter/foundation.dart';

import '../data/export_service.dart';
import '../data/tournee_repository.dart';
import '../journal.dart';
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
  DateTime? _dernierExport;
  bool _peutAnnulerImport = false;

  Campagne? get campagne => _campagne;

  /// Date du dernier export réussi, ou `null` si jamais exporté.
  DateTime? get dernierExport => _dernierExport;

  /// Une copie d'avant le dernier import existe : on peut l'annuler.
  bool get peutAnnulerImport => _peutAnnulerImport;

  /// Nombre de statuts enregistrés (y compris ceux d'un ancien jeu de bâtiments).
  int get nbEtatsEnregistres => _etats.length;

  /// Statuts enregistrés pour des bâtiments absents du jeu actuel.
  int get nbEtatsInconnus => _etats.keys.where((id) => !_parId.containsKey(id)).length;

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
    _dernierExport = await _repo.lireDernierExport();
    _peutAnnulerImport = await _repo.lireSauvegardeAvantImport() != null;
    notifyListeners();
  }

  // --- Export / import (F8) ---------------------------------------------

  /// Contenu du fichier d'export. Synchrone : l'interface peut ouvrir la
  /// feuille de partage dans la foulée du toucher (ARCHITECTURE §7.7).
  String contenuExport(DateTime maintenant) => ExportService.exporter(
        etats: _etats.values,
        versionBatiments: jeu.version,
        campagne: _campagne,
        maintenant: maintenant,
      );

  Future<void> noterExport(DateTime quand) async {
    _dernierExport = quand.toUtc();
    notifyListeners();
    await _repo.enregistrerDernierExport(_dernierExport!);
  }

  /// Lit un fichier d'export sans rien modifier.
  /// Lève une [FormatException] au message lisible si le fichier est refusé.
  ResultatImport lireImport(String texte) =>
      ExportService.lire(texte, idsConnus: _parId.keys.toSet(), versionBatiments: jeu.version);

  /// Remplace tous les statuts par ceux du fichier. Une copie de la tournée
  /// actuelle est gardée d'abord, pour pouvoir annuler ([annulerDernierImport]).
  Future<void> importer(ResultatImport resultat) async {
    await _repo.enregistrerSauvegardeAvantImport(contenuExport(_horloge()));
    await _repo.remplacerTout(resultat.etats);
    _remplacerEnMemoire(resultat.etats);
    _peutAnnulerImport = true;
    notifyListeners();
  }

  /// Remet la tournée telle qu'elle était juste avant le dernier import.
  Future<void> annulerDernierImport() async {
    final sauvegarde = await _repo.lireSauvegardeAvantImport();
    if (sauvegarde == null) return;
    final etats = ExportService.lire(sauvegarde, idsConnus: null, versionBatiments: jeu.version).etats;
    await _repo.remplacerTout(etats);
    await _repo.effacerSauvegardeAvantImport();
    _remplacerEnMemoire(etats);
    _peutAnnulerImport = false;
    notifyListeners();
  }

  void _remplacerEnMemoire(Iterable<EtatBatiment> etats) {
    _selectionId = null;
    _etats
      ..clear()
      ..addAll({for (final e in etats) e.batimentId: e});
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
      Journal.instance.ajouter('Échec d\'enregistrement de $batimentId : $e');
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
