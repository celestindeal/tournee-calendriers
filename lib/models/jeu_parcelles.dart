import 'package:latlong2/latlong.dart';

import 'commune.dart';
import 'parcelle.dart';

/// Contenu complet de `assets/data/parcelles.json` (généré par
/// tool/preparer_donnees.dart) : les parcelles de toutes les communes de la tournée.
class JeuParcelles {
  JeuParcelles({
    required this.version,
    required this.communes,
    required this.sources,
    required this.centre,
    required this.sudOuest,
    required this.nordEst,
    required this.parcelles,
  })  : parcelleDeLAncienId = {
          for (final p in parcelles)
            for (final ancien in p.anciensIds) ancien: p.id,
        },
        _nomParInsee = {for (final c in communes) c.insee: c.nom};

  /// Format attendu du fichier : 3 = plusieurs communes, suivi par parcelle.
  static const formatAttendu = 3;

  factory JeuParcelles.depuisJson(Map<String, dynamic> json) {
    if (json['format'] != formatAttendu) {
      throw FormatException('Fichier de parcelles au format ${json['format']} (attendu : $formatAttendu)');
    }
    final version = json['version'];
    if (version is! String || version.isEmpty) {
      throw const FormatException('Fichier de parcelles sans version');
    }
    final communes = [
      for (final c in json['communes'] as List) Commune.depuisJson(c as Map<String, dynamic>),
    ];
    if (communes.isEmpty) throw const FormatException('Fichier de parcelles sans commune');
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
      communes: communes,
      sources: [for (final s in (json['sources'] as Map).values) s as String],
      centre: _latLng(json['centre']),
      sudOuest: _latLng(bbox[0]),
      nordEst: _latLng(bbox[1]),
      parcelles: parcelles,
    );
  }

  /// Millésime du cadastre + empreinte du contenu, par ex. `2026-09-01-967fca8b`.
  /// Comparée à celle d'un export pour détecter une autre version de la carte.
  final String version;

  /// Les communes de la tournée. La première sert de vue de départ.
  final List<Commune> communes;

  /// Mentions de source à afficher (cadastre, BAN).
  final List<String> sources;

  /// Centre et emprise de toutes les communes réunies.
  final LatLng centre;
  final LatLng sudOuest;
  final LatLng nordEst;
  final List<Parcelle> parcelles;

  /// Ancien identifiant de bâtiment (suivi par bâtiment) → parcelle actuelle.
  final Map<String, String> parcelleDeLAncienId;

  final Map<String, String> _nomParInsee;

  /// Nom de la commune d'après son code INSEE (`null` si inconnu).
  String? nomCommune(String? insee) => _nomParInsee[insee];

  static LatLng _latLng(Object? valeur) {
    final l = valeur as List;
    return LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());
  }
}
