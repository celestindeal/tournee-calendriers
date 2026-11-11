import '../models/parcelle.dart';

/// Numéro et rue d'une adresse : « 12 bis Rue Apollo, La Grange » →
/// (12, « Rue Apollo »). Pour une parcelle à plusieurs adresses, la première
/// compte. Sans numéro : 0 ; sans adresse : rue « Adresse inconnue ».
({int numero, String rue}) decouperAdresse(String? adresse) {
  if (adresse == null || adresse.trim().isEmpty) return (numero: 0, rue: rueInconnue);
  final premiere = adresse.split(' / ').first.replaceFirst(RegExp(r'\s*\(\+\d+\)$'), '').trim();
  final m = RegExp(r'^(\d+)\s+(?:(?:bis|ter|quater|[a-z])\s+)?(.+)$', caseSensitive: false).firstMatch(premiere);
  final (numero, reste) = m == null ? (0, premiere) : (int.parse(m[1]!), m[2]!);
  // Le lieu-dit éventuel (« , La Grange ») ne sépare pas une rue en plusieurs groupes.
  return (numero: numero, rue: reste.split(', ').first.trim());
}

const rueInconnue = 'Adresse inconnue';

/// Un groupe de la liste : les maisons d'une rue, dans une commune.
class GroupeRue {
  GroupeRue({required this.insee, required this.rue, required this.parcelles});

  final String? insee;
  final String rue;
  final List<Parcelle> parcelles;
}

/// Range les parcelles par commune (dans l'ordre [ordreCommunes]), puis par
/// rue (ordre alphabétique sans accents, « Adresse inconnue » en dernier),
/// puis par numéro.
List<GroupeRue> grouperParRue(Iterable<Parcelle> parcelles, {required List<String> ordreCommunes}) {
  final groupes = <(String?, String), GroupeRue>{};
  final numeros = <String, int>{};
  for (final p in parcelles) {
    final (:numero, :rue) = decouperAdresse(p.adresse);
    numeros[p.id] = numero;
    groupes.putIfAbsent((p.codeInsee, rue), () => GroupeRue(insee: p.codeInsee, rue: rue, parcelles: [])).parcelles.add(p);
  }
  int rangCommune(String? insee) {
    final i = insee == null ? -1 : ordreCommunes.indexOf(insee);
    return i < 0 ? ordreCommunes.length : i;
  }

  final liste = groupes.values.toList()
    ..sort((a, b) {
      final c = rangCommune(a.insee).compareTo(rangCommune(b.insee));
      if (c != 0) return c;
      if ((a.rue == rueInconnue) != (b.rue == rueInconnue)) return a.rue == rueInconnue ? 1 : -1;
      final r = sansAccents(a.rue).compareTo(sansAccents(b.rue));
      // Même rue écrite avec et sans accent : ordre fixe (orthographe exacte).
      return r != 0 ? r : a.rue.compareTo(b.rue);
    });
  for (final g in liste) {
    g.parcelles.sort((a, b) {
      final n = numeros[a.id]!.compareTo(numeros[b.id]!);
      return n != 0 ? n : (a.adresse ?? a.id).compareTo(b.adresse ?? b.id);
    });
  }
  return liste;
}

/// Minuscules sans accents, pour trier « Église » avec les « E ».
String sansAccents(String texte) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', //
    'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'œ': 'oe', 'æ': 'ae', '’': "'",
  };
  final bas = texte.toLowerCase();
  final sb = StringBuffer();
  for (final r in bas.runes) {
    final c = String.fromCharCode(r);
    sb.write(accents[c] ?? c);
  }
  return sb.toString();
}
