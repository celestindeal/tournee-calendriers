import 'dart:convert';

import '../models/campagne.dart';
import '../models/etat_parcelle.dart';
import '../models/statut.dart';

/// Résultat de la lecture d'un fichier d'export.
class ResultatImport {
  const ResultatImport({
    required this.etats,
    required this.ignores,
    required this.autreVersionCarte,
    this.exporteLe,
  });

  /// États à importer (parcelles connues uniquement, sans « non visité »).
  final List<EtatParcelle> etats;

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
  }) {
    final liste = etats.where((e) => e.statut != Statut.nonVisite).toList()
      ..sort((a, b) => a.parcelleId.compareTo(b.parcelleId));
    return const JsonEncoder.withIndent(' ').convert({
      'format': format,
      'versionFormat': versionFormat,
      'exporteLe': maintenant.toUtc().toIso8601String(),
      'versionBatiments': versionCarte,
      if (campagne != null) 'campagne': {'debut': campagne.debut.toUtc().toIso8601String()},
      'etats': [
        for (final e in liste) {'id': e.parcelleId, 's': e.statut.name, 't': e.modifieLe.millisecondsSinceEpoch},
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

    final exporteLe = json['exporteLe'];
    return ResultatImport(
      etats: [for (final l in parId.values) EtatParcelle.lePlusParlant(l)],
      ignores: ignores,
      autreVersionCarte: json['versionBatiments'] != versionCarte,
      exporteLe: exporteLe is String ? DateTime.tryParse(exporteLe) : null,
    );
  }
}
