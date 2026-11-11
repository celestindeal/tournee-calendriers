import 'package:flutter/foundation.dart';

import '../data/export_service.dart';
import '../data/tournee_repository.dart';
import '../journal.dart';
import '../models/avancement.dart';
import '../models/parcelle.dart';
import '../models/campagne.dart';
import '../models/etat_parcelle.dart';
import '../models/jeu_parcelles.dart';
import '../models/statut.dart';
import 'migration.dart';

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
        _parId = {for (final b in jeu.parcelles) b.id: b};

  final TourneeRepository _repo;
  final DateTime Function() _horloge;
  final Map<String, Parcelle> _parId;

  /// Les parcelles de la commune (lecture seule).
  final JeuParcelles jeu;

  /// États enregistrés. Peut contenir des ids absents de [jeu] (ancienne version
  /// de la carte) : ils sont conservés mais pas comptés.
  final Map<String, EtatParcelle> _etats = {};

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

  /// Nombre de statuts enregistrés (y compris ceux absents de la carte actuelle).
  int get nbEtatsEnregistres => _etats.length;

  /// Statuts enregistrés pour des parcelles absentes de la carte actuelle.
  int get nbEtatsInconnus => _etats.keys.where((id) => !_parId.containsKey(id)).length;

  /// Message à afficher une fois (puis appeler [effacerErreur]).
  String? get derniereErreur => _derniereErreur;

  /// Nombre d'anciens statuts (suivi par bâtiment) reportés sur leur parcelle
  /// au dernier chargement (0 en temps normal).
  int get statutsReportes => _statutsReportes;
  int _statutsReportes = 0;

  /// Lit les statuts enregistrés. Crée la campagne au tout premier lancement.
  /// Reporte une fois pour toutes les statuts de l'ancien suivi par bâtiment
  /// sur leur parcelle (une copie d'avant le report est gardée dans la base).
  Future<void> charger() async {
    var etats = await _repo.lireEtats();
    final migration = reporterSurParcelles(
      etats,
      idsParcelles: _parId.keys.toSet(),
      parcelleDeLAncienId: jeu.parcelleDeLAncienId,
    );
    _statutsReportes = migration.reportes;
    if (migration.reportes > 0) {
      await _repo.enregistrerSauvegardeAvantParcelles(
        ExportService.exporter(
          etats: etats.values,
          versionCarte: 'suivi-par-batiment',
          maintenant: _horloge(),
        ),
      );
      await _repo.remplacerTout(migration.etats.values);
      etats = migration.etats;
      Journal.instance.ajouter('${migration.reportes} statut(s) de bâtiments reportés sur leur parcelle');
    }
    _etats
      ..clear()
      ..addAll(etats);
    _campagne = await _repo.lireCampagne();
    if (_campagne == null) {
      _campagne = Campagne(debut: _horloge().toUtc(), versionCarte: jeu.version);
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
        versionCarte: jeu.version,
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
  /// Un export fait avant le passage aux parcelles est reporté sur les parcelles.
  ResultatImport lireImport(String texte) => ExportService.lire(
        texte,
        idsConnus: _parId.keys.toSet(),
        versionCarte: jeu.version,
        correspondances: jeu.parcelleDeLAncienId,
      );

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
    final etats = ExportService.lire(
      sauvegarde,
      idsConnus: null,
      versionCarte: jeu.version,
      correspondances: jeu.parcelleDeLAncienId,
    ).etats;
    await _repo.remplacerTout(etats);
    await _repo.effacerSauvegardeAvantImport();
    _remplacerEnMemoire(etats);
    _peutAnnulerImport = false;
    notifyListeners();
  }

  void _remplacerEnMemoire(Iterable<EtatParcelle> etats) {
    _selectionId = null;
    _etats
      ..clear()
      ..addAll({for (final e in etats) e.parcelleId: e});
  }

  Statut statutDe(String parcelleId) => _etats[parcelleId]?.statut ?? Statut.nonVisite;

  Parcelle? parcelle(String id) => _parId[id];

  /// La parcelle dont le panneau est ouvert, ou `null`.
  Parcelle? get selection => _selectionId == null ? null : _parId[_selectionId];

  void selectionner(String? parcelleId) {
    final id = parcelleId != null && _parId.containsKey(parcelleId) ? parcelleId : null;
    if (id == _selectionId) return;
    _selectionId = id;
    notifyListeners();
  }

  Avancement get avancement => Avancement.calculer(
        nbParcelles: jeu.parcelles.length,
        statuts: [
          for (final e in _etats.entries)
            if (_parId.containsKey(e.key)) e.value.statut,
        ],
      );

  /// Change le statut d'une parcelle et l'enregistre immédiatement (F2, F3, F4).
  /// Renvoie `false` si l'enregistrement a échoué (l'ancien statut est remis).
  Future<bool> changerStatut(String parcelleId, Statut statut) async {
    if (!_parId.containsKey(parcelleId)) return false;
    final ancien = _etats[parcelleId];
    final nouveau = EtatParcelle(parcelleId: parcelleId, statut: statut, modifieLe: _horloge().toUtc());
    _appliquer(parcelleId, nouveau);
    notifyListeners();
    try {
      await _repo.enregistrer(nouveau);
      return true;
    } catch (e) {
      // Ne pas écraser un changement plus récent fait entre-temps.
      if (identical(_etats[parcelleId], nouveau) ||
          (statut == Statut.nonVisite && !_etats.containsKey(parcelleId))) {
        _appliquer(parcelleId, ancien);
      }
      _derniereErreur = 'Le statut n\'a pas pu être enregistré. Réessayez.';
      Journal.instance.ajouter('Échec d\'enregistrement de $parcelleId : $e');
      notifyListeners();
      return false;
    }
  }

  void effacerErreur() => _derniereErreur = null;

  void _appliquer(String parcelleId, EtatParcelle? etat) {
    if (etat == null || etat.statut == Statut.nonVisite) {
      _etats.remove(parcelleId);
    } else {
      _etats[parcelleId] = etat;
    }
  }
}
