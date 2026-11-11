import '../models/parcelle.dart';
import 'listes.dart';

/// Recherche d'adresse : « 12 prevert », « eglise fouillouse », « st heand »…
///
/// Chaque mot tapé doit se retrouver dans l'adresse ou le nom de la commune :
/// - un mot en lettres est le début d'un mot de l'adresse (« prev » trouve
///   « Prévert ») ;
/// - un nombre est un numéro entier (« 12 » trouve « 12 » et « 12 bis »,
///   pas « 112 »).
/// Les accents, majuscules et la ponctuation ne comptent pas.
class IndexAdresses {
  IndexAdresses(Iterable<Parcelle> parcelles, {required String? Function(String? insee) nomCommune, required List<String> ordreCommunes}) {
    for (final p in parcelles) {
      if (p.adresse == null) continue;
      _entrees.add((p, motsDe('${p.adresse} ${nomCommune(p.codeInsee) ?? ''}').toSet()));
    }
    // Ordre d'affichage fixe : commune, rue, numéro (comme les listes).
    final ordre = <String, int>{};
    var i = 0;
    for (final g in grouperParRue([for (final (p, _) in _entrees) p], ordreCommunes: ordreCommunes)) {
      for (final p in g.parcelles) {
        ordre[p.id] = i++;
      }
    }
    _entrees.sort((a, b) => ordre[a.$1.id]!.compareTo(ordre[b.$1.id]!));
  }

  final _entrees = <(Parcelle, Set<String>)>[];

  /// Nombre d'adresses dans lesquelles on peut chercher.
  int get taille => _entrees.length;

  /// Les parcelles qui correspondent, dans l'ordre commune / rue / numéro.
  /// Vide si la recherche ne contient aucun mot.
  List<Parcelle> chercher(String requete) {
    final mots = [for (final m in motsDe(requete)) _abreviations[m] ?? m];
    if (mots.isEmpty) return const [];
    return [
      for (final (p, motsAdresse) in _entrees)
        if (mots.every((m) => _trouve(m, motsAdresse))) p,
    ];
  }

  static bool _trouve(String mot, Set<String> motsAdresse) {
    if (_nombre.hasMatch(mot)) {
      // « 12 » : numéro exact, éventuellement suivi d'une lettre (« 12b »).
      return motsAdresse.any((w) => w == mot || (w.startsWith(mot) && _lettres.hasMatch(w.substring(mot.length))));
    }
    return motsAdresse.any((w) => w.startsWith(mot));
  }

  static final _nombre = RegExp(r'^\d+$');
  static final _lettres = RegExp(r'^[a-z]+$');

  /// Abréviations courantes tapées sur le téléphone.
  static const _abreviations = {
    'st': 'saint',
    'ste': 'sainte',
    'rte': 'route',
    'bd': 'boulevard',
    'chem': 'chemin',
    'all': 'allee',
  };
}

/// Mots d'un texte, en minuscules sans accents ni ponctuation :
/// « 8 bis Place d'Éculieu » → [8, bis, place, d, eculieu].
List<String> motsDe(String texte) =>
    sansAccents(texte).split(RegExp(r'[^a-z0-9]+')).where((m) => m.isNotEmpty).toList();
