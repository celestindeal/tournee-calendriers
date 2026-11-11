import 'statut.dart';

/// Filtre d'affichage de la carte (F9).
enum Filtre {
  toutes('Toutes'),
  nonVisitees('Non visitées'),
  aRepasser('À repasser');

  const Filtre(this.libelle);
  final String libelle;

  /// Vrai si une parcelle de ce statut est affichée avec ce filtre.
  bool garde(Statut statut) => switch (this) {
        toutes => true,
        nonVisitees => statut == Statut.nonVisite,
        aRepasser => statut == Statut.aRepasser,
      };
}
