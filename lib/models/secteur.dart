import 'package:latlong2/latlong.dart';

/// Une tournée des pompiers (« Tournée n°7 ») : un secteur de la carte,
/// délimité par un ou plusieurs contours. Sert seulement à l'affichage : on
/// peut toujours cocher une maison d'une autre tournée.
///
/// Une maison fait partie de la tournée si le centre de sa parcelle est à
/// l'intérieur d'un des contours.
class Secteur {
  Secteur({required this.numero, required this.nom, required this.contours});

  final int numero;

  /// Nom affiché, par exemple « Tournée n°7 ».
  final String nom;

  /// Contours (polygones fermés ou non : le dernier point rejoint le premier).
  final List<List<LatLng>> contours;

  /// Vrai si [point] est dans l'un des contours.
  bool contient(LatLng point) => contours.any((c) => _dansPolygone(point, c));

  /// Coins sud-ouest et nord-est de la tournée (pour centrer la carte dessus).
  ({LatLng sudOuest, LatLng nordEst}) get emprise {
    var sud = 90.0, ouest = 180.0, nord = -90.0, est = -180.0;
    for (final c in contours) {
      for (final p in c) {
        if (p.latitude < sud) sud = p.latitude;
        if (p.latitude > nord) nord = p.latitude;
        if (p.longitude < ouest) ouest = p.longitude;
        if (p.longitude > est) est = p.longitude;
      }
    }
    return (sudOuest: LatLng(sud, ouest), nordEst: LatLng(nord, est));
  }

  /// Lit `{"numero": 7, "nom": "Tournée n°7", "contours": [[[lat, lon], …]]}`.
  static Secteur depuisJson(Map<String, dynamic> json) => Secteur(
        numero: json['numero'] as int,
        nom: json['nom'] as String,
        contours: [
          for (final c in json['contours'] as List)
            [
              for (final p in (c as List).cast<List>()) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            ],
        ],
      );

  /// Lit le fichier assets/data/tournees.json (`{"format": 1, "tournees": […]}`),
  /// trié par numéro.
  static List<Secteur> listeDepuisJson(Map<String, dynamic> json) {
    if (json['format'] != 1) throw FormatException('Format de tournées inconnu : ${json['format']}');
    return [for (final t in json['tournees'] as List) depuisJson(t as Map<String, dynamic>)]
      ..sort((a, b) => a.numero.compareTo(b.numero));
  }

  /// Algorithme du lancer de rayon (pair-impair).
  static bool _dansPolygone(LatLng p, List<LatLng> poly) {
    var dedans = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude <
              (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude) {
        dedans = !dedans;
      }
    }
    return dedans;
  }
}
