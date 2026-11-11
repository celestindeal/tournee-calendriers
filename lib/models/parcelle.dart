import 'package:latlong2/latlong.dart';

/// Une parcelle cadastrale qui porte au moins un bâtiment : c'est l'unité de
/// suivi de la tournée. On touche un de ses bâtiments, toute la parcelle prend
/// la couleur du statut. En lecture seule (embarquée dans l'app).
class Parcelle {
  const Parcelle({
    required this.id,
    required this.contours,
    required this.batiments,
    required this.centre,
    required this.surfaceM2,
    this.adresse,
    this.codeInsee,
    this.anciensIds = const [],
  });

  /// Lit une parcelle au format de `assets/data/parcelles.json` :
  /// `{"id", "a"?, "s", "c": [lat, lon], "p": [contour…], "b": [contour…], "anciens": [id…]}`.
  factory Parcelle.depuisJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Parcelle sans identifiant');
    }
    final contours = _lireContours(json['p']);
    final batiments = _lireContours(json['b']);
    if (contours.isEmpty || batiments.isEmpty || [...contours, ...batiments].any((c) => c.length < 3)) {
      throw FormatException('Parcelle $id : contour invalide');
    }
    return Parcelle(
      id: id,
      contours: contours,
      batiments: batiments,
      centre: _latLng(json['c']),
      surfaceM2: (json['s'] as num).toDouble(),
      adresse: json['a'] as String?,
      codeInsee: json['co'] as String?,
      anciensIds: [for (final a in json['anciens'] as List? ?? const []) a as String],
    );
  }

  /// Identifiant cadastral officiel (ex. « 422340000B1353 »), ou « bat-… » pour
  /// un bâtiment hors de toute parcelle.
  final String id;

  /// Contour(s) de la parcelle (le terrain), sans point de fermeture.
  final List<List<LatLng>> contours;

  /// Contours des bâtiments de la parcelle : c'est eux qu'on touche.
  final List<List<LatLng>> batiments;

  /// Centre du bâtiment principal (le plus grand).
  final LatLng centre;

  /// Surface du terrain (contenance cadastrale), en m².
  final double surfaceM2;

  /// « 12 Rue Apollo », « 12 Rue Apollo / 14 Rue Apollo », ou `null`.
  final String? adresse;

  /// Code INSEE de la commune de la parcelle (ex. « 42234 »).
  final String? codeInsee;

  /// Identifiants des bâtiments de cette parcelle dans l'ancien suivi par
  /// bâtiment (avant le 11/11/2026) : servent à reporter les statuts déjà saisis.
  final List<String> anciensIds;

  static List<List<LatLng>> _lireContours(Object? valeur) => [
        for (final contour in valeur as List) [for (final point in contour as List) _latLng(point)],
      ];

  static LatLng _latLng(Object? valeur) {
    final l = valeur as List;
    return LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());
  }
}
