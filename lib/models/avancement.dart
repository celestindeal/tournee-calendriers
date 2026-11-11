import 'statut.dart';

/// Compteurs de la barre d'avancement (F5).
///
/// Règle (docs/ARCHITECTURE.md §4.6) :
/// - total = toutes les parcelles − « non concerné »
/// - faits = acheté + refus
class Avancement {
  const Avancement({
    required this.nbParcelles,
    required this.achetes,
    required this.refus,
    required this.aRepasser,
    required this.nonConcernes,
  });

  /// [statuts] : le statut de chaque parcelle **connue** qui a un état enregistré.
  /// Les parcelles sans état sont « non visité ».
  factory Avancement.calculer({required int nbParcelles, required Iterable<Statut> statuts}) {
    var achetes = 0, refus = 0, aRepasser = 0, nonConcernes = 0;
    for (final s in statuts) {
      switch (s) {
        case Statut.achete:
          achetes++;
        case Statut.refus:
          refus++;
        case Statut.aRepasser:
          aRepasser++;
        case Statut.nonConcerne:
          nonConcernes++;
        case Statut.nonVisite:
          break;
      }
    }
    return Avancement(
      nbParcelles: nbParcelles,
      achetes: achetes,
      refus: refus,
      aRepasser: aRepasser,
      nonConcernes: nonConcernes,
    );
  }

  final int nbParcelles;
  final int achetes;
  final int refus;
  final int aRepasser;
  final int nonConcernes;

  int get total => nbParcelles - nonConcernes;
  int get faits => achetes + refus;
  int get nonVisites => nbParcelles - achetes - refus - aRepasser - nonConcernes;

  /// Pourcentage arrondi à l'entier inférieur (on n'annonce jamais 100 % trop tôt).
  int get pourcentage => total <= 0 ? 0 : faits * 100 ~/ total;

  /// « 132 / 480 faits (27 %) – 45 à repasser »
  String get resume => '$faits / $total faits ($pourcentage %) – $aRepasser à repasser';
}
