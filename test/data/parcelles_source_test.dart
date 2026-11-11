import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/data/parcelles_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Vérifie le vrai fichier embarqué : il est bien déclaré dans pubspec.yaml
  // et lisible par l'app. À mettre à jour si on régénère les données.
  test('charge les parcelles de Saint-Héand embarquées dans l\'app', () async {
    final jeu = await ParcellesSource().charger();

    expect(jeu.codeInsee, '42234');
    expect(jeu.nomCommune, 'Saint-Héand');
    expect(jeu.version, '2026-09-01-c076d874');
    // 1 639 parcelles bâties + 4 bâtiments hors parcelle.
    expect(jeu.parcelles, hasLength(1643));
    expect(jeu.parcelles.where((p) => p.adresse != null).length, greaterThan(1550));
    expect(jeu.parcelles.fold<int>(0, (n, p) => n + p.batiments.length), 2457);

    // Les 2 457 bâtiments de l'ancien suivi ont chacun leur parcelle.
    expect(jeu.parcelleDeLAncienId, hasLength(2457));
    expect(jeu.parcelleDeLAncienId.values.toSet(), hasLength(1643));

    // Tout est dans l'emprise de la commune.
    for (final p in jeu.parcelles) {
      expect(p.centre.latitude, inInclusiveRange(jeu.sudOuest.latitude, jeu.nordEst.latitude));
      expect(p.centre.longitude, inInclusiveRange(jeu.sudOuest.longitude, jeu.nordEst.longitude));
    }
  });
}
