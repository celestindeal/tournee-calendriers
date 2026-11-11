import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/data/parcelles_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Vérifie le vrai fichier embarqué : il est bien déclaré dans pubspec.yaml
  // et lisible par l'app. À mettre à jour si on régénère les données.
  test('charge les parcelles des 6 communes embarquées dans l\'app', () async {
    final jeu = await ParcellesSource().charger();

    expect(jeu.version, '2026-09-01-967fca8b');
    expect(
      jeu.communes.map((c) => '${c.insee} ${c.nom}'),
      [
        '42234 Saint-Héand',
        '42010 Aveizieux',
        '42206 Saint-Bonnet-les-Oules',
        '42100 La Gimond',
        '42096 Fontanès',
        '42097 La Fouillouse',
      ],
    );
    expect(jeu.parcelles, hasLength(5776));
    expect(jeu.parcelles.fold<int>(0, (n, p) => n + p.batiments.length), 7696);
    expect(jeu.parcelles.where((p) => p.adresse != null).length, greaterThan(5550));

    // Chaque parcelle connaît sa commune.
    final parCommune = <String?, int>{};
    for (final p in jeu.parcelles) {
      parCommune[p.codeInsee] = (parCommune[p.codeInsee] ?? 0) + 1;
    }
    expect(parCommune, {'42234': 1643, '42010': 889, '42206': 867, '42100': 153, '42096': 358, '42097': 1866});

    // Saint-Héand : les 2 457 bâtiments de l'ancien suivi ont toujours leur parcelle
    // (report des maisons cochées avant le passage aux parcelles).
    final saintHeand = jeu.parcelles.where((p) => p.codeInsee == '42234');
    expect(saintHeand.fold<int>(0, (n, p) => n + p.anciensIds.length), 2457);
    expect(jeu.parcelleDeLAncienId['u054gtt5m'], isNotNull);

    // Tout est dans l'emprise des communes.
    for (final p in jeu.parcelles) {
      expect(p.centre.latitude, inInclusiveRange(jeu.sudOuest.latitude, jeu.nordEst.latitude));
      expect(p.centre.longitude, inInclusiveRange(jeu.sudOuest.longitude, jeu.nordEst.longitude));
    }
  });
}
