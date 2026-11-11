import 'package:latlong2/latlong.dart';

/// Une commune de la tournée.
class Commune {
  const Commune({
    required this.insee,
    required this.nom,
    required this.sudOuest,
    required this.nordEst,
  });

  factory Commune.depuisJson(Map<String, dynamic> json) {
    final bbox = json['bbox'] as List;
    return Commune(
      insee: json['insee'] as String,
      nom: json['nom'] as String,
      sudOuest: _latLng(bbox[0]),
      nordEst: _latLng(bbox[1]),
    );
  }

  final String insee;
  final String nom;

  /// Emprise de la commune (ses parcelles bâties).
  final LatLng sudOuest;
  final LatLng nordEst;

  static LatLng _latLng(Object? valeur) {
    final l = valeur as List;
    return LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());
  }
}
