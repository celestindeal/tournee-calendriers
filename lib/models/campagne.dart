/// La tournée en cours (une par an en général).
class Campagne {
  const Campagne({required this.debut, required this.versionBatiments});

  static Campagne? depuisStockage(Map<String, Object?> valeur) {
    final debut = valeur['debut'];
    final version = valeur['versionBatiments'];
    if (debut is! int || version is! String) return null;
    return Campagne(
      debut: DateTime.fromMillisecondsSinceEpoch(debut, isUtc: true),
      versionBatiments: version,
    );
  }

  final DateTime debut;

  /// Version du fichier de bâtiments utilisé pendant cette campagne.
  final String versionBatiments;

  Map<String, Object> versStockage() => {
        'debut': debut.millisecondsSinceEpoch,
        'versionBatiments': versionBatiments,
      };

  @override
  bool operator ==(Object other) =>
      other is Campagne && other.debut.isAtSameMomentAs(debut) && other.versionBatiments == versionBatiments;

  @override
  int get hashCode => Object.hash(debut.millisecondsSinceEpoch, versionBatiments);
}
