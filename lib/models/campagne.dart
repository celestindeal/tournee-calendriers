/// La tournée en cours : une campagne par année.
class Campagne {
  /// [annee] : par défaut, l'année de début (heure locale).
  Campagne({required this.debut, required this.versionCarte, int? annee}) : annee = annee ?? debut.toLocal().year;

  static Campagne? depuisStockage(Map<String, Object?> valeur) {
    final debut = valeur['debut'];
    final version = valeur['versionBatiments'];
    final annee = valeur['annee'];
    if (debut is! int || version is! String) return null;
    return Campagne(
      debut: DateTime.fromMillisecondsSinceEpoch(debut, isUtc: true),
      versionCarte: version,
      // Les campagnes enregistrées avant le 11/11/2026 n'ont pas d'année.
      annee: annee is int ? annee : null,
    );
  }

  final DateTime debut;

  /// Année de la campagne (« Campagne 2026 »).
  final int annee;

  /// Version de la carte (fichier de parcelles) utilisée pendant cette campagne.
  final String versionCarte;

  Map<String, Object> versStockage() => {
        'debut': debut.millisecondsSinceEpoch,
        'versionBatiments': versionCarte,
        'annee': annee,
      };

  @override
  bool operator ==(Object other) =>
      other is Campagne &&
      other.debut.isAtSameMomentAs(debut) &&
      other.versionCarte == versionCarte &&
      other.annee == annee;

  @override
  int get hashCode => Object.hash(debut.millisecondsSinceEpoch, versionCarte, annee);
}
