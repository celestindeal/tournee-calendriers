import 'package:flutter/foundation.dart';

import '../data/export_service.dart';
import '../data/tournee_repository.dart';
import '../journal.dart';
import '../models/archive_campagne.dart';
import '../models/avancement.dart';
import '../models/campagne.dart';
import '../models/etat_parcelle.dart';
import '../models/filtre.dart';
import '../models/jeu_parcelles.dart';
import '../models/memo.dart';
import '../models/parcelle.dart';
import '../models/statut.dart';
import '../synchro/changement.dart';
import '../synchro/synchro_controller.dart';
import 'migration.dart';

/// État de la tournée affiché par l'interface (docs/ARCHITECTURE.md §5.1).
///
/// Chaque changement met d'abord l'écran à jour (instantané), puis est écrit
/// dans la base. Si l'écriture échoue, l'ancien état est remis et
/// [derniereErreur] est renseignée.
class TourneeController extends ChangeNotifier {
  TourneeController({required this._repo, required this.jeu, DateTime Function()? horloge})
    : _horloge = horloge ?? DateTime.now,
      _parId = {for (final b in jeu.parcelles) b.id: b};

  /// Nombre de campagnes terminées gardées (les plus anciennes sont effacées :
  /// on ne conserve pas l'historique des maisons indéfiniment, RGPD).
  static const campagnesArchiveesGardees = 2;

  final TourneeRepository _repo;
  final DateTime Function() _horloge;
  final Map<String, Parcelle> _parId;

  /// Les parcelles des communes de la tournée (lecture seule).
  final JeuParcelles jeu;

  /// États enregistrés. Peut contenir des ids absents de [jeu] (ancienne version
  /// de la carte) : ils sont conservés mais pas comptés.
  final Map<String, EtatParcelle> _etats = {};

  /// Mémos par parcelle (gardés d'une campagne à l'autre).
  final Map<String, Set<Memo>> _memos = {};

  /// Date de la dernière modification des mémos de chaque parcelle.
  final Map<String, DateTime> _datesMemos = {};

  /// Synchronisation entre téléphones (null tant qu'elle n'est pas branchée).
  SynchroController? synchro;

  /// Appelé après chaque modification enregistrée sur ce téléphone (pour
  /// l'envoyer aux autres). Pas appelé pour ce qui vient des autres téléphones.
  void Function(List<Changement>)? surChangementsLocaux;

  /// Campagnes terminées, de la plus récente à la plus ancienne.
  List<ArchiveCampagne> _archives = const [];

  String? _selectionId;
  Campagne? _campagne;
  String? _derniereErreur;
  DateTime? _dernierExport;
  bool _peutAnnulerImport = false;
  Filtre _filtre = Filtre.toutes;

  Campagne? get campagne => _campagne;
  List<ArchiveCampagne> get archives => _archives;

  /// Date du dernier export réussi, ou `null` si jamais exporté.
  DateTime? get dernierExport => _dernierExport;

  /// Une copie d'avant le dernier import existe : on peut l'annuler.
  bool get peutAnnulerImport => _peutAnnulerImport;

  /// Nombre de statuts enregistrés (y compris ceux absents de la carte actuelle).
  int get nbEtatsEnregistres => _etats.length;

  /// Statuts enregistrés pour des parcelles absentes de la carte actuelle.
  int get nbEtatsInconnus => _etats.keys.where((id) => !_parId.containsKey(id)).length;

  /// Nombre de parcelles qui ont au moins un mémo.
  int get nbParcellesAvecMemos => _memos.length;

  /// Message à afficher une fois (puis appeler [effacerErreur]).
  String? get derniereErreur => _derniereErreur;

  /// Nombre d'anciens statuts (suivi par bâtiment) reportés sur leur parcelle
  /// au dernier chargement (0 en temps normal).
  int get statutsReportes => _statutsReportes;
  int _statutsReportes = 0;

  /// Lit les statuts, mémos et campagnes enregistrés. Crée la campagne au tout
  /// premier lancement. Reporte une fois pour toutes les statuts de l'ancien
  /// suivi par bâtiment sur leur parcelle (une copie est gardée dans la base).
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
        ExportService.exporter(etats: etats.values, versionCarte: 'suivi-par-batiment', maintenant: _horloge()),
      );
      await _repo.remplacerTout(migration.etats.values);
      etats = migration.etats;
      Journal.instance.ajouter('${migration.reportes} statut(s) de bâtiments reportés sur leur parcelle');
    }
    _etats
      ..clear()
      ..addAll(etats);
    _memos
      ..clear()
      ..addAll(await _repo.lireMemos());
    _datesMemos
      ..clear()
      ..addAll(await _repo.lireDatesMemos());
    _archives = await _repo.lireArchives();
    _campagne = await _repo.lireCampagne();
    if (_campagne == null) {
      _campagne = Campagne(debut: _horloge().toUtc(), versionCarte: jeu.version);
      await _repo.enregistrerCampagne(_campagne!);
    }
    _dernierExport = await _repo.lireDernierExport();
    _peutAnnulerImport = await _repo.lireSauvegardeAvantImport() != null;
    notifyListeners();
  }

  // --- Statuts ----------------------------------------------------------

  Statut statutDe(String parcelleId) => _etats[parcelleId]?.statut ?? Statut.nonVisite;

  /// L'état enregistré (statut et date), ou `null` si non visitée.
  EtatParcelle? etatDe(String parcelleId) => _etats[parcelleId];

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
      _signaler([_changementStatut(nouveau)]);
      return true;
    } catch (e) {
      // Ne pas écraser un changement plus récent fait entre-temps.
      if (identical(_etats[parcelleId], nouveau) || (statut == Statut.nonVisite && !_etats.containsKey(parcelleId))) {
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

  // --- Mémos ------------------------------------------------------------

  Set<Memo> memosDe(String parcelleId) => _memos[parcelleId] ?? const {};

  /// Coche ou décoche un mémo et l'enregistre immédiatement.
  /// Renvoie `false` si l'enregistrement a échoué (l'ancien état est remis).
  Future<bool> basculerMemo(String parcelleId, Memo memo) async {
    if (!_parId.containsKey(parcelleId)) return false;
    final avant = memosDe(parcelleId);
    final apres = {...avant};
    if (!apres.remove(memo)) apres.add(memo);
    _appliquerMemos(parcelleId, apres);
    notifyListeners();
    final quand = _horloge().toUtc();
    try {
      await _repo.enregistrerMemos(parcelleId, apres, quand);
      _datesMemos[parcelleId] = quand;
      _signaler([Changement.memos(parcelleId: parcelleId, memos: apres, t: quand.millisecondsSinceEpoch)]);
      return true;
    } catch (e) {
      _appliquerMemos(parcelleId, avant);
      _derniereErreur = 'Le mémo n\'a pas pu être enregistré. Réessayez.';
      Journal.instance.ajouter('Échec d\'enregistrement des mémos de $parcelleId : $e');
      notifyListeners();
      return false;
    }
  }

  void _appliquerMemos(String parcelleId, Set<Memo> memos) {
    if (memos.isEmpty) {
      _memos.remove(parcelleId);
    } else {
      _memos[parcelleId] = memos;
    }
  }

  // --- Filtre d'affichage (F9) --------------------------------------------

  Filtre get filtre => _filtre;

  void changerFiltre(Filtre filtre) {
    if (filtre == _filtre) return;
    _filtre = filtre;
    // La maison sélectionnée peut disparaître de la carte : on ferme le panneau.
    if (_selectionId != null && !_filtre.garde(statutDe(_selectionId!))) _selectionId = null;
    notifyListeners();
  }

  /// Vrai si la parcelle est affichée avec le filtre actuel.
  bool estVisible(String parcelleId) => _filtre.garde(statutDe(parcelleId));

  // --- Campagnes (F11) ----------------------------------------------------

  /// Statut de la parcelle lors de la dernière campagne terminée, ou `null`.
  ({int annee, Statut statut})? statutPrecedent(String parcelleId) {
    if (_archives.isEmpty) return null;
    final derniere = _archives.first;
    final statut = derniere.statuts[parcelleId];
    return statut == null ? null : (annee: derniere.annee, statut: statut);
  }

  /// Termine la campagne en cours et en commence une nouvelle pour [annee] :
  /// les statuts sont archivés (consultables : « en 2026 : acheté »), puis
  /// toutes les maisons repassent en « non visité ». Les mémos sont gardés.
  /// Seules les [campagnesArchiveesGardees] dernières archives sont conservées.
  Future<void> nouvelleCampagne(int annee) async {
    final actuelle = _campagne;
    if (actuelle != null && annee <= actuelle.annee) {
      throw ArgumentError('La nouvelle campagne doit être postérieure à ${actuelle.annee}.');
    }
    final maintenant = _horloge().toUtc();
    if (actuelle != null) {
      await _repo.enregistrerArchive(
        ArchiveCampagne(
          annee: actuelle.annee,
          debut: actuelle.debut,
          fin: maintenant,
          versionCarte: actuelle.versionCarte,
          statuts: {for (final e in _etats.values) e.parcelleId: e.statut},
        ),
      );
    }
    var archives = await _repo.lireArchives();
    for (final ancienne in archives.skip(campagnesArchiveesGardees)) {
      await _repo.supprimerArchive(ancienne.annee);
    }
    archives = archives.take(campagnesArchiveesGardees).toList();

    await _repo.remplacerTout(const []);
    // La copie d'avant import concerne l'ancienne campagne : on ne doit plus pouvoir la restaurer.
    await _repo.effacerSauvegardeAvantImport();
    _campagne = Campagne(debut: maintenant, versionCarte: jeu.version, annee: annee);
    await _repo.enregistrerCampagne(_campagne!);

    _archives = archives;
    _remplacerEnMemoire(const []);
    _peutAnnulerImport = false;
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
    memos: _memos,
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

  /// Remplace tous les statuts (et les mémos, si le fichier en contient) par
  /// ceux du fichier. Une copie de la tournée actuelle est gardée d'abord,
  /// pour pouvoir annuler ([annulerDernierImport]).
  Future<void> importer(ResultatImport resultat) async {
    await _repo.enregistrerSauvegardeAvantImport(contenuExport(_horloge()));
    await _appliquerImport(resultat);
    _peutAnnulerImport = true;
    _signaler(toutPourSynchro());
    notifyListeners();
  }

  /// Remet la tournée telle qu'elle était juste avant le dernier import.
  Future<void> annulerDernierImport() async {
    final sauvegarde = await _repo.lireSauvegardeAvantImport();
    if (sauvegarde == null) return;
    final resultat = ExportService.lire(
      sauvegarde,
      idsConnus: null,
      versionCarte: jeu.version,
      correspondances: jeu.parcelleDeLAncienId,
    );
    await _appliquerImport(resultat);
    await _repo.effacerSauvegardeAvantImport();
    _peutAnnulerImport = false;
    _signaler(toutPourSynchro());
    notifyListeners();
  }

  Future<void> _appliquerImport(ResultatImport resultat) async {
    await _repo.remplacerTout(resultat.etats);
    _remplacerEnMemoire(resultat.etats);
    final memos = resultat.memos;
    if (memos != null) {
      final quand = _horloge().toUtc();
      await _repo.remplacerMemos(memos, quand);
      _memos
        ..clear()
        ..addAll({
          for (final e in memos.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        });
      _datesMemos
        ..clear()
        ..addAll({for (final id in _memos.keys) id: quand});
    }
  }

  void _remplacerEnMemoire(Iterable<EtatParcelle> etats) {
    _selectionId = null;
    _etats
      ..clear()
      ..addAll({for (final e in etats) e.parcelleId: e});
  }
  // --- Synchronisation entre téléphones -----------------------------------

  void _signaler(List<Changement> changements) {
    if (changements.isNotEmpty) surChangementsLocaux?.call(changements);
  }

  Changement _changementStatut(EtatParcelle e) => Changement.statut(
    parcelleId: e.parcelleId,
    campagne: _campagne!.annee,
    statut: e.statut,
    t: e.modifieLe.millisecondsSinceEpoch,
  );

  /// Tous les statuts de la campagne en cours et tous les mémos, pour un
  /// premier envoi au serveur (le serveur garde ce qui est le plus récent).
  List<Changement> toutPourSynchro() => [
    if (_campagne != null)
      for (final e in _etats.values)
        if (_parId.containsKey(e.parcelleId)) _changementStatut(e),
    for (final MapEntry(key: id, value: m) in _memos.entries)
      if (_parId.containsKey(id))
        Changement.memos(parcelleId: id, memos: m, t: (_datesMemos[id] ?? DateTime.utc(2000)).millisecondsSinceEpoch),
  ];

  /// Date (ms) de ce que ce téléphone connaît pour ce changement, ou `null`.
  int? dateLocale(Changement c) => switch (c.type) {
    TypeChangement.statut =>
      c.campagne == _campagne?.annee ? _etats[c.parcelleId]?.modifieLe.millisecondsSinceEpoch : null,
    TypeChangement.memos => _datesMemos[c.parcelleId]?.millisecondsSinceEpoch,
  };

  /// Applique des changements reçus des autres téléphones (déjà reconnus plus
  /// récents). Ignore les maisons inconnues de la carte et les statuts d'une
  /// autre campagne.
  Future<void> appliquerDistants(List<Changement> changements) async {
    var modifie = false;
    for (final c in changements) {
      if (!_parId.containsKey(c.parcelleId)) continue;
      switch (c.type) {
        case TypeChangement.statut:
          final statut = c.statut;
          if (statut == null || c.campagne != _campagne?.annee) continue;
          final etat = EtatParcelle(parcelleId: c.parcelleId, statut: statut, modifieLe: c.date);
          await _repo.enregistrer(etat);
          _appliquer(c.parcelleId, etat);
          if (_selectionId == c.parcelleId && !_filtre.garde(statut)) _selectionId = null;
        case TypeChangement.memos:
          await _repo.enregistrerMemos(c.parcelleId, c.memos, c.date);
          _appliquerMemos(c.parcelleId, c.memos);
          if (c.memos.isEmpty) {
            _datesMemos.remove(c.parcelleId);
          } else {
            _datesMemos[c.parcelleId] = c.date;
          }
      }
      modifie = true;
    }
    if (modifie) notifyListeners();
  }
}
