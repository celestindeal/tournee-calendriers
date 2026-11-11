import 'package:latlong2/latlong.dart';

import 'batiment.dart';

/// Contenu complet de `assets/data/batiments.json`.
class JeuBatiments {
  const JeuBatiments({
    required this.version,
    required this.codeInsee,
    required this.nomCommune,
    required this.sources,
    required this.centre,
    required this.sudOuest,
    required this.nordEst,
    required this.batiments,
  });

  factory JeuBatiments.depuisJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! String || version.isEmpty) {
      throw const FormatException('Fichier de bâtiments sans version');
    }
    final commune = json['commune'] as Map<String, dynamic>;
    final bbox = json['bbox'] as List;
    final batiments = [
      for (final b in json['batiments'] as List) Batiment.depuisJson(b as Map<String, dynamic>),
    ];
    final ids = <String>{};
    for (final b in batiments) {
      if (!ids.add(b.id)) throw FormatException('Identifiant de bâtiment en double : ${b.id}');
    }
    return JeuBatiments(
      version: version,
      codeInsee: commune['insee'] as String,
      nomCommune: commune['nom'] as String,
      sources: [for (final s in (json['sources'] as Map).values) s as String],
      centre: _latLng(json['centre']),
      sudOuest: _latLng(bbox[0]),
      nordEst: _latLng(bbox[1]),
      batiments: batiments,
    );
  }

  /// Millésime du cadastre + empreinte du contenu, par ex. `2026-09-01-6c5672c1`.
  /// Comparée à celle d'un export pour détecter un autre jeu de bâtiments.
  final String version;

  final String codeInsee;
  final String nomCommune;

  /// Mentions de source à afficher (cadastre, BAN).
  final List<String> sources;

  final LatLng centre;
  final LatLng sudOuest;
  final LatLng nordEst;
  final List<Batiment> batiments;

  static LatLng _latLng(Object? valeur) {
    final l = valeur as List;
    return LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());
  }
}
