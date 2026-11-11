import 'statut.dart';

/// Ce qui est enregistré sur l'iPhone pour une parcelle : un id, un statut, une date.
/// Rien d'autre (RGPD, voir le cahier des charges §8).
class EtatParcelle {
  const EtatParcelle({required this.parcelleId, required this.statut, required this.modifieLe});

  /// Quand plusieurs statuts tombent sur la même parcelle (anciens bâtiments
  /// d'une même parcelle, ancien export) : le plus récent parmi acheté / refus /
  /// à repasser ; « non concerné » seulement s'il n'y a rien d'autre (un garage
  /// marqué « non concerné » ne doit pas masquer la maison « achetée »).
  static EtatParcelle lePlusParlant(Iterable<EtatParcelle> etats) {
    EtatParcelle? plusRecent(Iterable<EtatParcelle> l) =>
        l.isEmpty ? null : l.reduce((a, b) => b.modifieLe.isAfter(a.modifieLe) ? b : a);
    final parlants = etats.where((e) => e.statut != Statut.nonConcerne && e.statut != Statut.nonVisite);
    return plusRecent(parlants) ?? plusRecent(etats)!;
  }

  /// Le même état, rattaché à une autre parcelle.
  EtatParcelle pour(String autreId) => EtatParcelle(parcelleId: autreId, statut: statut, modifieLe: modifieLe);

  /// Relit un enregistrement `{"s": "achete", "t": 1762850000000}`.
  /// Renvoie `null` si l'enregistrement est illisible (statut inconnu, date absente).
  static EtatParcelle? depuisStockage(String parcelleId, Map<String, Object?> valeur) {
    final s = valeur['s'];
    final t = valeur['t'];
    if (s is! String || t is! int) return null;
    final statut = Statut.depuisNom(s);
    if (statut == null) return null;
    return EtatParcelle(
      parcelleId: parcelleId,
      statut: statut,
      modifieLe: DateTime.fromMillisecondsSinceEpoch(t, isUtc: true),
    );
  }

  final String parcelleId;
  final Statut statut;
  final DateTime modifieLe;

  Map<String, Object> versStockage() => {
        's': statut.name,
        't': modifieLe.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) =>
      other is EtatParcelle &&
      other.parcelleId == parcelleId &&
      other.statut == statut &&
      other.modifieLe.isAtSameMomentAs(modifieLe);

  @override
  int get hashCode => Object.hash(parcelleId, statut, modifieLe.millisecondsSinceEpoch);

  @override
  String toString() => 'EtatParcelle($parcelleId, ${statut.name}, ${modifieLe.toIso8601String()})';
}
