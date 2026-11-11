import 'package:latlong2/latlong.dart';

import 'parcelle.dart';

/// Contenu complet de `assets/data/parcelles.json` (généré par
/// tool/preparer_donnees.dart).
class JeuParcelles {
  JeuParcelles({
    required this.version,
    required this.codeInsee,
    required this.nomCommune,
    required this.sources,
    required this.centre,
    required this.sudOuest,
    required this.nordEst,
    required this.parcelles,
  }) : parcelleDeLAncienId = {
          for (final p in parcelles)
            for (final ancien in p.anciensIds) ancien: p.id,
        };

  /// Format attendu du fichier : 2 = suivi par parcelle.
  static const formatAttendu = 2;

  factory JeuParcelles.depuisJson(Map<String, dynamic> json) {
    if (json['format'] != formatAttendu) {
      throw FormatException('Fichier de parcelles au format ${json['format']} (attendu : $formatAttendu)');
    }
    final version = json['version'];
    if (version is! String || version.isEmpty) {
      throw const FormatException('Fichier de parcelles sans version');
    }
    final commune = json['commune'] as Map<String, dynamic>;
    final bbox = json['bbox'] as List;
    final parcelles = [
      for (final p in json['parcelles'] as List) Parcelle.depuisJson(p as Map<String, dynamic>),
    ];
    final ids = <String>{};
    for (final p in parcelles) {
      if (!ids.add(p.id)) throw FormatException('Identifiant de parcelle en double : ${p.id}');
    }
    return JeuParcelles(
      version: version,
      codeInsee: commune['insee'] as String,
      nomCommune: commune['nom'] as String,
      sources: [for (final s in (json['sources'] as Map).values) s as String],
      centre: _latLng(json['centre']),
      sudOuest: _latLng(bbox[0]),
      nordEst: _latLng(bbox[1]),
      parcelles: parcelles,
    );
  }

  /// Millésime du cadastre + empreinte du contenu, par ex. `2026-09-01-c076d874`.
  /// Comparée à celle d'un export pour détecter une autre version de la carte.
  final String version;

  final String codeInsee;
  final String nomCommune;

  /// Mentions de source à afficher (cadastre, BAN).
  final List<String> sources;

  final LatLng centre;
  final LatLng sudOuest;
  final LatLng nordEst;
  final List<Parcelle> parcelles;

  /// Ancien identifiant de bâtiment (suivi par bâtiment) → parcelle actuelle.
  final Map<String, String> parcelleDeLAncienId;

  static LatLng _latLng(Object? valeur) {
    final l = valeur as List;
    return LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());
  }
}
