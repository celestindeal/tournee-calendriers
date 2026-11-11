import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../state/position_controller.dart';

/// Positions GPS de l'appareil (navigator.geolocation sur le web).
/// N'est appelé qu'au toucher du bouton « Me localiser » (ARCHITECTURE §7.6).
Stream<PositionGps> fluxGeolocator() => Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 2),
    ).map((p) => PositionGps(LatLng(p.latitude, p.longitude), p.accuracy));
