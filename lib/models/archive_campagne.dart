import 'statut.dart';

/// Une campagne terminée, gardée pour consultation (« en 2026 : acheté »).
/// Seul le statut final de chaque parcelle est gardé (pas les dates), et
/// seulement pour les dernières campagnes (voir TourneeController).
class ArchiveCampagne {
  const ArchiveCampagne({
    required this.annee,
    required this.debut,
    required this.fin,
    required this.versionCarte,
    required this.statuts,
  });

  static ArchiveCampagne? depuisStockage(Map<String, Object?> valeur) {
    final annee = valeur['annee'];
    final debut = valeur['debut'];
    final fin = valeur['fin'];
    final version = valeur['versionBatiments'];
    final etats = valeur['etats'];
    if (annee is! int || debut is! int || fin is! int || version is! String || etats is! Map) return null;
    return ArchiveCampagne(
      annee: annee,
      debut: DateTime.fromMillisecondsSinceEpoch(debut, isUtc: true),
      fin: DateTime.fromMillisecondsSinceEpoch(fin, isUtc: true),
      versionCarte: version,
      statuts: {
        for (final MapEntry(:key, :value) in etats.entries)
          if (key is String && value is String && Statut.depuisNom(value) != null) key: Statut.depuisNom(value)!,
      },
    );
  }

  final int annee;
  final DateTime debut;
  final DateTime fin;
  final String versionCarte;

  /// Statut final de chaque parcelle visitée (les « non visité » sont absentes).
  final Map<String, Statut> statuts;

  int nombre(Statut statut) => statuts.values.where((s) => s == statut).length;

  Map<String, Object> versStockage() => {
        'annee': annee,
        'debut': debut.millisecondsSinceEpoch,
        'fin': fin.millisecondsSinceEpoch,
        'versionBatiments': versionCarte,
        'etats': {for (final MapEntry(:key, :value) in statuts.entries) key: value.name},
      };
}
