import 'package:latlong2/latlong.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tournee_calendriers/data/tournee_repository.dart';
import 'package:tournee_calendriers/models/parcelle.dart';
import 'package:tournee_calendriers/models/jeu_parcelles.dart';
import 'package:tournee_calendriers/platform/plateforme.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';

/// Petit jeu de 3 parcelles pour les tests.
/// Anciens identifiants de bâtiments (suivi par bâtiment) : « a » regroupait
/// la maison « vieux-a1 » et le garage « vieux-a2 », « b » le bâtiment « vieux-b1 ».
JeuParcelles jeuDeTest() {
  Parcelle p(String id, String? adresse, double lat, List<String> anciens) => Parcelle(
        id: id,
        adresse: adresse,
        surfaceM2: 944,
        centre: LatLng(lat, 4.38),
        contours: [
          [LatLng(lat, 4.38), LatLng(lat + 0.0003, 4.38), LatLng(lat, 4.3803)],
        ],
        batiments: [
          [LatLng(lat, 4.38), LatLng(lat + 0.0001, 4.38), LatLng(lat, 4.3801)],
        ],
        anciensIds: anciens,
      );
  return JeuParcelles(
    version: 'test-1',
    codeInsee: '42234',
    nomCommune: 'Saint-Héand',
    sources: const ['Cadastre', 'BAN'],
    centre: const LatLng(45.53, 4.38),
    sudOuest: const LatLng(45.50, 4.34),
    nordEst: const LatLng(45.56, 4.42),
    parcelles: [
      p('a', '7 Rue Jacques Prévert', 45.51, ['vieux-a1', 'vieux-a2']),
      p('b', '13 Rue de l’Avenir', 45.52, ['vieux-b1']),
      p('c', null, 45.53, const []),
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

/// Navigateur simulé pour les tests (pages Menu et Diagnostic).
class PlateformeDeTest implements Plateforme {
  PlateformeDeTest({this.estAppInstallee = true});

  @override
  final bool estAppInstallee;

  @override
  String get navigateur => 'Navigateur de test';

  @override
  Future<bool> stockagePersistant() async => true;

  @override
  Future<String> serviceWorker() async => 'actif · app-test : 27';
}

extension CopieJeu on JeuParcelles {
  /// Le même jeu sans un bâtiment (simule un jeu de bâtiments régénéré).
  JeuParcelles copieSans(String id) => JeuParcelles(
        version: version,
        codeInsee: codeInsee,
        nomCommune: nomCommune,
        sources: sources,
        centre: centre,
        sudOuest: sudOuest,
        nordEst: nordEst,
        parcelles: [for (final b in parcelles) if (b.id != id) b],
      );
}
