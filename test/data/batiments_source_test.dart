import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/data/batiments_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Vérifie le vrai fichier embarqué : il est bien déclaré dans pubspec.yaml
  // et lisible par l'app. À mettre à jour si on régénère les données.
  test('charge les bâtiments de Saint-Héand embarqués dans l\'app', () async {
    final jeu = await BatimentsSource().charger();

    expect(jeu.codeInsee, '42234');
    expect(jeu.nomCommune, 'Saint-Héand');
    expect(jeu.version, '2026-09-01-6c5672c1');
    expect(jeu.batiments, hasLength(2457));
    expect(jeu.batiments.where((b) => b.adresse != null).length, greaterThan(2300));

    // Tous les bâtiments sont dans l'emprise de la commune.
    for (final b in jeu.batiments) {
      expect(b.centre.latitude, inInclusiveRange(jeu.sudOuest.latitude, jeu.nordEst.latitude));
      expect(b.centre.longitude, inInclusiveRange(jeu.sudOuest.longitude, jeu.nordEst.longitude));
    }
  });
}
