import '../models/etat_parcelle.dart';

/// Résultat du report des anciens statuts (suivi par bâtiment) sur les parcelles.
class ResultatMigration {
  const ResultatMigration(this.etats, this.reportes);

  /// Les états après report, par identifiant.
  final Map<String, EtatParcelle> etats;

  /// Nombre d'anciens états de bâtiments reportés sur une parcelle.
  final int reportes;
}

/// Reporte les statuts saisis par bâtiment (avant le 11/11/2026) sur la
/// parcelle de chaque bâtiment. Plusieurs statuts sur une même parcelle :
/// voir [EtatParcelle.lePlusParlant]. Les identifiants inconnus et sans
/// correspondance sont gardés tels quels (rien n'est jamais jeté).
ResultatMigration reporterSurParcelles(
  Map<String, EtatParcelle> etats, {
  required Set<String> idsParcelles,
  required Map<String, String> parcelleDeLAncienId,
}) {
  final candidats = <String, List<EtatParcelle>>{};
  var reportes = 0;
  for (final MapEntry(key: id, value: etat) in etats.entries) {
    final cible = idsParcelles.contains(id) ? id : parcelleDeLAncienId[id];
    if (cible == null) {
      candidats[id] = [etat]; // inconnu : gardé
      continue;
    }
    if (cible != id) reportes++;
    candidats.putIfAbsent(cible, () => []).add(etat.pour(cible));
  }
  return ResultatMigration(
    {for (final MapEntry(key: id, value: l) in candidats.entries) id: EtatParcelle.lePlusParlant(l)},
    reportes,
  );
}
