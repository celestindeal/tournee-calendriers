/// Familles de mémos, dans l'ordre d'affichage.
enum GroupeMemo {
  attention('À savoir'),
  moment('Quand passer'),
  jour('Quel jour');

  const GroupeMemo(this.titre);
  final String titre;
}

/// Mémo rapide sur une maison. Des étiquettes à cocher, pas de texte libre
/// (RGPD, cahier des charges §8).
///
/// ⚠️ Le nom de chaque valeur (`chien`, `soir`…) est écrit dans la base de
/// l'iPhone et dans les exports : ne jamais le renommer sans migration.
enum Memo {
  chien('Chien', GroupeMemo.attention),
  pasDeDemarchage('Pas de démarchage', GroupeMemo.attention),
  motLaisse('Mot laissé', GroupeMemo.attention),
  matin('Le matin', GroupeMemo.moment),
  midi('Le midi', GroupeMemo.moment),
  soir('Le soir', GroupeMemo.moment),
  weekend('Le week-end', GroupeMemo.moment),
  lundi('Lundi', GroupeMemo.jour, 'Lun'),
  mardi('Mardi', GroupeMemo.jour, 'Mar'),
  mercredi('Mercredi', GroupeMemo.jour, 'Mer'),
  jeudi('Jeudi', GroupeMemo.jour, 'Jeu'),
  vendredi('Vendredi', GroupeMemo.jour, 'Ven'),
  samedi('Samedi', GroupeMemo.jour, 'Sam'),
  dimanche('Dimanche', GroupeMemo.jour, 'Dim');

  const Memo(this.libelle, this.groupe, [this.court]);

  final String libelle;
  final GroupeMemo groupe;

  /// Libellé court (jours de la semaine), sinon le libellé.
  final String? court;
  String get etiquette => court ?? libelle;

  /// Retrouve un mémo à partir de son nom stocké, ou `null` s'il est inconnu.
  static Memo? depuisNom(String nom) => _parNom[nom];
  static final Map<String, Memo> _parNom = values.asNameMap();

  /// Lit une liste de noms stockés ; les noms inconnus sont ignorés.
  static Set<Memo> depuisNoms(Iterable<Object?> noms) => {
        for (final n in noms)
          if (n is String && depuisNom(n) != null) depuisNom(n)!,
      };

  /// Noms à stocker, dans l'ordre de l'énumération (sortie stable).
  static List<String> versNoms(Set<Memo> memos) => [
        for (final m in values)
          if (memos.contains(m)) m.name,
      ];
}
