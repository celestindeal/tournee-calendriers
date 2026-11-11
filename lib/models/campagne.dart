/// La tournée en cours (une par an en général).
class Campagne {
  const Campagne({required this.debut, required this.versionCarte});

  static Campagne? depuisStockage(Map<String, Object?> valeur) {
    final debut = valeur['debut'];
    final version = valeur['versionBatiments'];
    if (debut is! int || version is! String) return null;
    return Campagne(
      debut: DateTime.fromMillisecondsSinceEpoch(debut, isUtc: true),
      versionCarte: version,
    );
  }

  final DateTime debut;

  /// Version de la carte (fichier de parcelles) utilisée pendant cette campagne.
  final String versionCarte;

  Map<String, Object> versStockage() => {
        'debut': debut.millisecondsSinceEpoch,
        'versionBatiments': versionCarte,
      };

  @override
  bool operator ==(Object other) =>
      other is Campagne && other.debut.isAtSameMomentAs(debut) && other.versionCarte == versionCarte;

  @override
  int get hashCode => Object.hash(debut.millisecondsSinceEpoch, versionCarte);
}
