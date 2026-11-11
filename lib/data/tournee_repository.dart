import 'package:sembast/sembast.dart';

import '../models/campagne.dart';
import '../models/etat_batiment.dart';
import '../models/statut.dart';

/// Lecture et écriture des statuts sur l'appareil.
///
/// La base est fournie de l'extérieur : `databaseFactoryWeb` (IndexedDB) dans
/// l'app, `newDatabaseFactoryMemory()` dans les tests.
///
/// Stores (docs/ARCHITECTURE.md §4.4) :
/// - `etats` : id du bâtiment → `{"s": statut, "t": date en ms}`.
///   Absence d'enregistrement = « non visité ».
/// - `meta`  : `"campagne"` → `{"debut", "versionBatiments"}` ;
///   `"dernierExport"` → `{"t"}` ; `"sauvegardeAvantImport"` → `{"json"}`.
class TourneeRepository {
  TourneeRepository._(this._db);

  static const nomBase = 'tournee.db';

  /// À augmenter (avec une migration dans [ouvrir]) si le format stocké change.
  static const versionSchema = 1;

  static final _etats = stringMapStoreFactory.store('etats');
  static final _meta = stringMapStoreFactory.store('meta');
  static const _cleCampagne = 'campagne';
  static const _cleDernierExport = 'dernierExport';
  static const _cleSauvegarde = 'sauvegardeAvantImport';

  final Database _db;

  static Future<TourneeRepository> ouvrir(DatabaseFactory fabrique, {String nom = nomBase}) async {
    final db = await fabrique.openDatabase(nom, version: versionSchema);
    return TourneeRepository._(db);
  }

  /// Tous les états enregistrés. Les enregistrements illisibles sont ignorés
  /// (ils ne doivent pas empêcher l'app de démarrer).
  Future<Map<String, EtatBatiment>> lireEtats() async {
    final enregistrements = await _etats.find(_db);
    final etats = <String, EtatBatiment>{};
    for (final e in enregistrements) {
      final etat = EtatBatiment.depuisStockage(e.key, e.value);
      if (etat != null) etats[e.key] = etat;
    }
    return etats;
  }

  /// Enregistre un état. « Non visité » supprime l'enregistrement.
  /// Le `Future` ne se termine qu'une fois l'écriture faite dans la base.
  Future<void> enregistrer(EtatBatiment etat) async {
    final ref = _etats.record(etat.batimentId);
    if (etat.statut == Statut.nonVisite) {
      await ref.delete(_db);
    } else {
      await ref.put(_db, etat.versStockage());
    }
  }

  /// Remplace tous les états d'un coup, en une seule transaction :
  /// soit tout est écrit, soit rien ne change (import, nouvelle campagne).
  Future<void> remplacerTout(Iterable<EtatBatiment> etats) async {
    await _db.transaction((txn) async {
      await _etats.delete(txn);
      for (final etat in etats) {
        if (etat.statut == Statut.nonVisite) continue;
        await _etats.record(etat.batimentId).put(txn, etat.versStockage());
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

  Future<void> fermer() => _db.close();
}
