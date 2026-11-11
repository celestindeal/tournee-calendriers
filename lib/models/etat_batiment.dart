import 'statut.dart';

/// Ce qui est enregistré sur l'iPhone pour un bâtiment : un id, un statut, une date.
/// Rien d'autre (RGPD, voir le cahier des charges §8).
class EtatBatiment {
  const EtatBatiment({required this.batimentId, required this.statut, required this.modifieLe});

  /// Relit un enregistrement `{"s": "achete", "t": 1762850000000}`.
  /// Renvoie `null` si l'enregistrement est illisible (statut inconnu, date absente).
  static EtatBatiment? depuisStockage(String batimentId, Map<String, Object?> valeur) {
    final s = valeur['s'];
    final t = valeur['t'];
    if (s is! String || t is! int) return null;
    final statut = Statut.depuisNom(s);
    if (statut == null) return null;
    return EtatBatiment(
      batimentId: batimentId,
      statut: statut,
      modifieLe: DateTime.fromMillisecondsSinceEpoch(t, isUtc: true),
    );
  }

  final String batimentId;
  final Statut statut;
  final DateTime modifieLe;

  Map<String, Object> versStockage() => {
        's': statut.name,
        't': modifieLe.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) =>
      other is EtatBatiment &&
      other.batimentId == batimentId &&
      other.statut == statut &&
      other.modifieLe.isAtSameMomentAs(modifieLe);

  @override
  int get hashCode => Object.hash(batimentId, statut, modifieLe.millisecondsSinceEpoch);

  @override
  String toString() => 'EtatBatiment($batimentId, ${statut.name}, ${modifieLe.toIso8601String()})';
}
