import 'package:sembast/sembast.dart';

import '../models/archive_campagne.dart';
import '../models/campagne.dart';
import '../models/etat_parcelle.dart';
import '../models/memo.dart';
import '../models/statut.dart';

/// Lecture et écriture des statuts sur l'appareil.
///
/// La base est fournie de l'extérieur : `databaseFactoryWeb` (IndexedDB) dans
/// l'app, `newDatabaseFactoryMemory()` dans les tests.
///
/// Stores (docs/ARCHITECTURE.md §4.4) :
/// - `etats` : id de la parcelle → `{"s": statut, "t": date en ms}`.
///   Absence d'enregistrement = « non visité ».
/// - `meta`  : `"campagne"` → `{"debut", "versionBatiments", "annee"}` ;
///   `"dernierExport"` → `{"t"}` ; `"sauvegardeAvantImport"` → `{"json"}`.
/// - `memos` : id de la parcelle → `{"m": [noms des mémos], "t": date en ms}`.
///   Gardés d'une campagne à l'autre. Absence = aucun mémo.
/// - `archives` : année → campagne terminée (statut de chaque parcelle).
class TourneeRepository {
  TourneeRepository._(this._db);

  static const nomBase = 'tournee.db';

  /// À augmenter (avec une migration dans [ouvrir]) si le format stocké change.
  static const versionSchema = 1;

  static final _etats = stringMapStoreFactory.store('etats');
  static final _meta = stringMapStoreFactory.store('meta');
  static final _memos = stringMapStoreFactory.store('memos');
  static final _archives = stringMapStoreFactory.store('archives');
  static const _cleCampagne = 'campagne';
  static const _cleDernierExport = 'dernierExport';
  static const _cleSauvegarde = 'sauvegardeAvantImport';
  static const _cleSauvegardeParcelles = 'sauvegardeAvantParcelles';

  final Database _db;

  static Future<TourneeRepository> ouvrir(DatabaseFactory fabrique, {String nom = nomBase}) async {
    final db = await fabrique.openDatabase(nom, version: versionSchema);
    return TourneeRepository._(db);
  }

  /// Tous les états enregistrés. Les enregistrements illisibles sont ignorés
  /// (ils ne doivent pas empêcher l'app de démarrer).
  Future<Map<String, EtatParcelle>> lireEtats() async {
    final enregistrements = await _etats.find(_db);
    final etats = <String, EtatParcelle>{};
    for (final e in enregistrements) {
      final etat = EtatParcelle.depuisStockage(e.key, e.value);
      if (etat != null) etats[e.key] = etat;
    }
    return etats;
  }

  /// Enregistre un état. « Non visité » supprime l'enregistrement.
  /// Le `Future` ne se termine qu'une fois l'écriture faite dans la base.
  Future<void> enregistrer(EtatParcelle etat) async {
    final ref = _etats.record(etat.parcelleId);
    if (etat.statut == Statut.nonVisite) {
      await ref.delete(_db);
    } else {
      await ref.put(_db, etat.versStockage());
    }
  }

  /// Remplace tous les états d'un coup, en une seule transaction :
  /// soit tout est écrit, soit rien ne change (import, nouvelle campagne).
  Future<void> remplacerTout(Iterable<EtatParcelle> etats) async {
    await _db.transaction((txn) async {
      await _etats.delete(txn);
      for (final etat in etats) {
        if (etat.statut == Statut.nonVisite) continue;
        await _etats.record(etat.parcelleId).put(txn, etat.versStockage());
      }
    });
  }

  Future<Campagne?> lireCampagne() async {
    final valeur = await _meta.record(_cleCampagne).get(_db);
    return valeur == null ? null : Campagne.depuisStockage(valeur);
  }

  Future<void> enregistrerCampagne(Campagne campagne) async {
    await _meta.record(_cleCampagne).put(_db, campagne.versStockage());
  }

  /// Date du dernier export réussi (pour « Dernier export : il y a 3 jours »).
  Future<DateTime?> lireDernierExport() async {
    final t = (await _meta.record(_cleDernierExport).get(_db))?['t'];
    return t is int ? DateTime.fromMillisecondsSinceEpoch(t, isUtc: true) : null;
  }

  Future<void> enregistrerDernierExport(DateTime quand) async {
    await _meta.record(_cleDernierExport).put(_db, {'t': quand.millisecondsSinceEpoch});
  }

  /// Copie de la tournée (au format d'export) faite juste avant un import,
  /// pour pouvoir l'annuler.
  Future<String?> lireSauvegardeAvantImport() async {
    final json = (await _meta.record(_cleSauvegarde).get(_db))?['json'];
    return json is String ? json : null;
  }

  Future<void> enregistrerSauvegardeAvantImport(String json) async {
    await _meta.record(_cleSauvegarde).put(_db, {'json': json});
  }

  Future<void> effacerSauvegardeAvantImport() async {
    await _meta.record(_cleSauvegarde).delete(_db);
  }

  /// Copie (au format d'export) des statuts de l'ancien suivi par bâtiment,
  /// faite juste avant leur report sur les parcelles. Gardée par sécurité.
  Future<String?> lireSauvegardeAvantParcelles() async {
    final json = (await _meta.record(_cleSauvegardeParcelles).get(_db))?['json'];
    return json is String ? json : null;
  }

  Future<void> enregistrerSauvegardeAvantParcelles(String json) async {
    await _meta.record(_cleSauvegardeParcelles).put(_db, {'json': json});
  }

  // --- Mémos (gardés d'une campagne à l'autre) ----------------------------

  Future<Map<String, Set<Memo>>> lireMemos() async {
    final memos = <String, Set<Memo>>{};
    for (final e in await _memos.find(_db)) {
      final m = e.value['m'];
      if (m is! List) continue;
      final lus = Memo.depuisNoms(m);
      if (lus.isNotEmpty) memos[e.key] = lus;
    }
    return memos;
  }

  /// Enregistre les mémos d'une parcelle ; aucun mémo supprime l'enregistrement.
  Future<void> enregistrerMemos(String parcelleId, Set<Memo> memos, DateTime quand) async {
    final ref = _memos.record(parcelleId);
    if (memos.isEmpty) {
      await ref.delete(_db);
    } else {
      await ref.put(_db, {'m': Memo.versNoms(memos), 't': quand.millisecondsSinceEpoch});
    }
  }

  /// Remplace tous les mémos d'un coup, en une seule transaction (import).
  Future<void> remplacerMemos(Map<String, Set<Memo>> memos, DateTime quand) async {
    await _db.transaction((txn) async {
      await _memos.delete(txn);
      for (final MapEntry(key: id, value: m) in memos.entries) {
        if (m.isEmpty) continue;
        await _memos.record(id).put(txn, {'m': Memo.versNoms(m), 't': quand.millisecondsSinceEpoch});
      }
    });
  }

  // --- Archives des campagnes terminées -----------------------------------

  /// Les campagnes archivées, de la plus récente à la plus ancienne.
  Future<List<ArchiveCampagne>> lireArchives() async {
    final archives = [
      for (final e in await _archives.find(_db)) ?ArchiveCampagne.depuisStockage(e.value),
    ]..sort((a, b) => b.annee.compareTo(a.annee));
    return archives;
  }

  Future<void> enregistrerArchive(ArchiveCampagne archive) async {
    await _archives.record('${archive.annee}').put(_db, archive.versStockage());
  }

  Future<void> supprimerArchive(int annee) async {
    await _archives.record('$annee').delete(_db);
  }

  Future<void> fermer() => _db.close();
}
