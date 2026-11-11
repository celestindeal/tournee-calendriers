import 'dart:ui' show Color;

/// Statut d'une parcelle pendant la tournée.
///
/// ⚠️ Le nom de chaque valeur (`achete`, `aRepasser`…) est écrit dans la base
/// de l'iPhone et dans les exports : ne jamais le renommer sans migration.
enum Statut {
  nonVisite('Non visité', Color(0xFF9E9E9E)),
  achete('Fait – acheté', Color(0xFF2E7D32)),
  aRepasser('À repasser', Color(0xFFEF6C00)),
  refus('Fait – refus', Color(0xFFC62828)),
  nonConcerne('Non concerné', Color(0xFF1565C0));

  const Statut(this.libelle, this.couleur);

  final String libelle;
  final Color couleur;

  /// Compte comme « fait » dans l'avancement (décision du 11/11/2026 :
  /// un refus compte comme fait).
  bool get estFait => this == achete || this == refus;

  /// Retrouve un statut à partir de son nom stocké, ou `null` s'il est inconnu.
  static Statut? depuisNom(String nom) => _parNom[nom];

  static final Map<String, Statut> _parNom = values.asNameMap();
}
