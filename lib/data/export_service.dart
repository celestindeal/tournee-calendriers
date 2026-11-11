import 'dart:convert';

import '../models/campagne.dart';
import '../models/etat_parcelle.dart';
import '../models/memo.dart';
import '../models/statut.dart';

/// Résultat de la lecture d'un fichier d'export.
class ResultatImport {
  const ResultatImport({
    required this.etats,
    required this.ignores,
    required this.autreVersionCarte,
    this.exporteLe,
    this.memos,
  });

  /// États à importer (parcelles connues uniquement, sans « non visité »).
  final List<EtatParcelle> etats;

  /// Mémos du fichier, ou `null` si le fichier n'en contient pas (export
  /// antérieur aux mémos) : on garde alors ceux du téléphone.
  final Map<String, Set<Memo>>? memos;

  /// Nombre d'états ignorés car la maison n'existe pas sur la carte de l'app.
  final int ignores;

  /// Le fichier a été fait avec une autre version de la carte.
  final bool autreVersionCarte;

  final DateTime? exporteLe;
}

/// Export / import de la tournée dans un fichier JSON (F8, ARCHITECTURE §4.5).
class ExportService {
  static const format = 'tournee-calendriers';
  static const versionFormat = 1;

  static const _pasUnExport = 'Ce fichier n\'est pas une sauvegarde de l\'appli tournée.';
  static const _abime = 'Ce fichier de sauvegarde est abîmé : il ne peut pas être importé.';

  /// « tournee-2026-11-11-1832.json » (heure locale).
  static String nomFichier(DateTime maintenant) {
    final t = maintenant.toLocal();
    String d(int n) => n.toString().padLeft(2, '0');
    return 'tournee-${t.year}-${d(t.month)}-${d(t.day)}-${d(t.hour)}${d(t.minute)}.json';
  }

  static String exporter({
    required Iterable<EtatParcelle> etats,
    required String versionCarte,
    required DateTime maintenant,
    Campagne? campagne,
    Map<String, Set<Memo>> memos = const {},
  }) {
    final liste = etats.where((e) => e.statut != Statut.nonVisite).toList()
      ..sort((a, b) => a.parcelleId.compareTo(b.parcelleId));
    return const JsonEncoder.withIndent(' ').convert({
      'format': format,
      'versionFormat': versionFormat,
      'exporteLe': maintenant.toUtc().toIso8601String(),
      'versionBatiments': versionCarte,
      if (campagne != null) 'campagne': {'debut': campagne.debut.toUtc().toIso8601String(), 'annee': campagne.annee},
      'etats': [
        for (final e in liste) {'id': e.parcelleId, 's': e.statut.name, 't': e.modifieLe.millisecondsSinceEpoch},
      ],
      'memos': [
        for (final id in memos.keys.toList()..sort())
          if (memos[id]!.isNotEmpty) {'id': id, 'm': Memo.versNoms(memos[id]!)},
      ],
    });
  }

  /// Lit un export. [idsConnus] : parcelles de l'app (les autres sont ignorées) ;
  /// `null` pour tout garder (restauration de la sauvegarde d'avant import).
  /// [correspondances] : ancien identifiant de bâtiment → parcelle, pour lire un
  /// export fait avant le passage aux parcelles (voir [EtatParcelle.lePlusParlant]).
  /// Lève une [FormatException] au message lisible si le fichier est refusé.
  static ResultatImport lire(
    String texte, {
    required Set<String>? idsConnus,
    required String versionCarte,
    Map<String, String> correspondances = const {},
  }) {
    final Object? json;
    try {
      json = jsonDecode(texte);
    } on FormatException {
      throw const FormatException(_pasUnExport);
    }
    if (json is! Map || json['format'] != format) throw const FormatException(_pasUnExport);
    final vf = json['versionFormat'];
    if (vf is! int) throw const FormatException(_abime);
    if (vf > versionFormat) {
      throw const FormatException(
        'Ce fichier vient d\'une version plus récente de l\'appli : mettez l\'appli à jour puis réessayez.',
      );
    }
    final liste = json['etats'];
    if (liste is! List) throw const FormatException(_abime);

    final parId = <String, List<EtatParcelle>>{};
    var ignores = 0;
    for (final e in liste) {
      if (e is! Map) throw const FormatException(_abime);
      final id = e['id'];
      if (id is! String || id.isEmpty) throw const FormatException(_abime);
      final etat = EtatParcelle.depuisStockage(id, {'s': e['s'], 't': e['t']});
      if (etat == null) throw const FormatException(_abime);
      final cible = idsConnus == null
          ? correspondances[id] ?? id // restauration : tout est gardé
          : idsConnus.contains(id)
              ? id
              : correspondances[id];
      if (cible == null) {
        ignores++;
        continue;
      }
      if (etat.statut == Statut.nonVisite) continue;
      parId.putIfAbsent(cible, () => []).add(etat.pour(cible));
    }

    // Mémos (absents des exports faits avant leur création).
    Map<String, Set<Memo>>? memos;
    final listeMemos = json['memos'];
    if (listeMemos is List) {
      memos = {};
      for (final e in listeMemos) {
        if (e is! Map || e['id'] is! String || e['m'] is! List) throw const FormatException(_abime);
        final id = e['id'] as String;
        final cible = idsConnus == null
            ? correspondances[id] ?? id
            : idsConnus.contains(id)
                ? id
                : correspondances[id];
        if (cible == null) continue;
        final lus = Memo.depuisNoms(e['m'] as List);
        if (lus.isNotEmpty) memos.putIfAbsent(cible, () => {}).addAll(lus);
      }
    }

    final exporteLe = json['exporteLe'];
    return ResultatImport(
      etats: [for (final l in parId.values) EtatParcelle.lePlusParlant(l)],
      ignores: ignores,
      autreVersionCarte: json['versionBatiments'] != versionCarte,
      exporteLe: exporteLe is String ? DateTime.tryParse(exporteLe) : null,
      memos: memos,
    );
  }
}
