import 'package:latlong2/latlong.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tournee_calendriers/data/tournee_repository.dart';
import 'package:tournee_calendriers/models/batiment.dart';
import 'package:tournee_calendriers/models/jeu_batiments.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';

/// Petit jeu de 3 bâtiments pour les tests.
JeuBatiments jeuDeTest() {
  Batiment b(String id, String? adresse, double lat) => Batiment(
        id: id,
        adresse: adresse,
        surfaceM2: 100,
        centre: LatLng(lat, 4.38),
        contours: [
          [LatLng(lat, 4.38), LatLng(lat + 0.0001, 4.38), LatLng(lat, 4.3801)],
        ],
      );
  return JeuBatiments(
    version: 'test-1',
    codeInsee: '42234',
    nomCommune: 'Saint-Héand',
    sources: const ['Cadastre', 'BAN'],
    centre: const LatLng(45.53, 4.38),
    sudOuest: const LatLng(45.50, 4.34),
    nordEst: const LatLng(45.56, 4.42),
    batiments: [
      b('a', '7 Rue Jacques Prévert', 45.51),
      b('b', '13 Rue de l’Avenir', 45.52),
      b('c', null, 45.53),
    ],
  );
}

/// Contrôleur prêt à l'emploi sur une base en mémoire neuve.
Future<(TourneeController, TourneeRepository, DatabaseFactory)> controleurDeTest({
  DateTime Function()? horloge,
}) async {
  final fabrique = newDatabaseFactoryMemory();
  final repo = await TourneeRepository.ouvrir(fabrique);
  final controller = TourneeController(repo: repo, jeu: jeuDeTest(), horloge: horloge);
  await controller.charger();
  return (controller, repo, fabrique);
}

extension CopieJeu on JeuBatiments {
  /// Le même jeu sans un bâtiment (simule un jeu de bâtiments régénéré).
  JeuBatiments copieSans(String id) => JeuBatiments(
        version: version,
        codeInsee: codeInsee,
        nomCommune: nomCommune,
        sources: sources,
        centre: centre,
        sudOuest: sudOuest,
        nordEst: nordEst,
        batiments: [for (final b in batiments) if (b.id != id) b],
      );
}
