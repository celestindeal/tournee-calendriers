import 'package:latlong2/latlong.dart';

/// Un bâtiment du cadastre, en lecture seule (embarqué dans l'app).
class Batiment {
  const Batiment({
    required this.id,
    required this.contours,
    required this.centre,
    required this.surfaceM2,
    this.adresse,
  });

  /// Lit un bâtiment au format de `assets/data/batiments.json` :
  /// `{"id", "a"?, "s", "c": [lat, lon], "p": [[[lat, lon], …], …]}`.
  factory Batiment.depuisJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Bâtiment sans identifiant');
    }
    final contours = [
      for (final contour in json['p'] as List) [for (final point in contour as List) _latLng(point)],
    ];
    if (contours.isEmpty || contours.any((c) => c.length < 3)) {
      throw FormatException('Bâtiment $id : contour invalide');
    }
    return Batiment(
      id: id,
      contours: contours,
      centre: _latLng(json['c']),
      surfaceM2: (json['s'] as num).toDouble(),
      adresse: json['a'] as String?,
    );
  }

  /// Stable d'une génération à l'autre (géohash du centre, voir tool/preparer_donnees.dart).
  final String id;

  /// Une liste de points par partie du bâtiment, sans point de fermeture.
  final List<List<LatLng>> contours;

  final LatLng centre;
  final double surfaceM2;

  /// « 12 Rue Apollo », ou `null` si aucune adresse à moins de 60 m.
  final String? adresse;

  static LatLng _latLng(Object? valeur) {
    final l = valeur as List;
    return LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());
  }
}
