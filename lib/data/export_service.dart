import 'dart:convert';

import '../models/campagne.dart';
import '../models/etat_batiment.dart';
import '../models/statut.dart';

/// Résultat de la lecture d'un fichier d'export.
class ResultatImport {
  const ResultatImport({
    required this.etats,
    required this.ignores,
    required this.autreVersionBatiments,
    this.exporteLe,
  });

  /// États à importer (bâtiments connus uniquement, sans « non visité »).
  final List<EtatBatiment> etats;

  /// Nombre d'états ignorés car le bâtiment n'existe pas dans l'app.
  final int ignores;

  /// Le fichier a été fait avec un autre jeu de bâtiments.
  final bool autreVersionBatiments;

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
    required Iterable<EtatBatiment> etats,
    required String versionBatiments,
    required DateTime maintenant,
    Campagne? campagne,
  }) {
    final liste = etats.where((e) => e.statut != Statut.nonVisite).toList()
      ..sort((a, b) => a.batimentId.compareTo(b.batimentId));
    return const JsonEncoder.withIndent(' ').convert({
      'format': format,
      'versionFormat': versionFormat,
      'exporteLe': maintenant.toUtc().toIso8601String(),
      'versionBatiments': versionBatiments,
      if (campagne != null) 'campagne': {'debut': campagne.debut.toUtc().toIso8601String()},
      'etats': [
        for (final e in liste) {'id': e.batimentId, 's': e.statut.name, 't': e.modifieLe.millisecondsSinceEpoch},
      ],
    });
  }

  /// Lit un export. [idsConnus] : bâtiments de l'app (les autres sont ignorés) ;
  /// `null` pour tout garder (restauration de la sauvegarde d'avant import).
  /// Lève une [FormatException] au message lisible si le fichier est refusé.
  static ResultatImport lire(String texte, {required Set<String>? idsConnus, required String versionBatiments}) {
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

    final parId = <String, EtatBatiment>{};
    var ignores = 0;
    for (final e in liste) {
      if (e is! Map) throw const FormatException(_abime);
      final id = e['id'];
      if (id is! String || id.isEmpty) throw const FormatException(_abime);
      final etat = EtatBatiment.depuisStockage(id, {'s': e['s'], 't': e['t']});
      if (etat == null) throw const FormatException(_abime);
      if (idsConnus != null && !idsConnus.contains(id)) {
        ignores++;
        continue;
      }
      if (etat.statut == Statut.nonVisite) continue;
      parId[id] = etat;
    }

    final exporteLe = json['exporteLe'];
    return ResultatImport(
      etats: parId.values.toList(),
      ignores: ignores,
      autreVersionBatiments: json['versionBatiments'] != versionBatiments,
      exporteLe: exporteLe is String ? DateTime.tryParse(exporteLe) : null,
    );
  }
}
