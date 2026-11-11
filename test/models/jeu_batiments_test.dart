import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/models/jeu_batiments.dart';

Map<String, dynamic> _jeu({List<Map<String, dynamic>>? batiments}) => {
      'version': '2026-09-01-abcd1234',
      'commune': {'insee': '42234', 'nom': 'Saint-Héand'},
      'sources': {'cadastre': 'Cadastre', 'adresses': 'BAN'},
      'centre': [45.53, 4.38],
      'bbox': [
        [45.50, 4.34],
        [45.56, 4.42],
      ],
      'batiments': batiments ??
          [
            {
              'id': 'u054gtt5m',
              'a': '7 Rue Jacques Prévert',
              's': 136.6,
              'c': [45.514197, 4.379658],
              'p': [
                [
                  [45.5141, 4.3796],
                  [45.5142, 4.3797],
                  [45.5143, 4.3795],
                ],
              ],
            },
            {
              'id': 'u054fumme',
              's': 22,
              'c': [45, 4],
              'p': [
                [
                  [45, 4],
                  [45.0001, 4],
                  [45, 4.0001],
                ],
              ],
            },
          ],
    };

void main() {
  test('lit le format produit par tool/preparer_donnees.dart', () {
    final jeu = JeuBatiments.depuisJson(_jeu());
    expect(jeu.version, '2026-09-01-abcd1234');
    expect(jeu.nomCommune, 'Saint-Héand');
    expect(jeu.sources, ['Cadastre', 'BAN']);
    expect(jeu.batiments, hasLength(2));

    final b = jeu.batiments.first;
    expect(b.id, 'u054gtt5m');
    expect(b.adresse, '7 Rue Jacques Prévert');
    expect(b.contours.single, hasLength(3));
    expect(b.centre.latitude, 45.514197);

    // Coordonnées entières et adresse absente acceptées.
    final sansAdresse = jeu.batiments.last;
    expect(sansAdresse.adresse, isNull);
    expect(sansAdresse.surfaceM2, 22.0);
  });

  test('refuse un identifiant en double', () {
    final b = _jeu()['batiments'][0] as Map<String, dynamic>;
    expect(() => JeuBatiments.depuisJson(_jeu(batiments: [b, b])), throwsFormatException);
  });

  test('refuse un contour de moins de 3 points', () {
    expect(
      () => JeuBatiments.depuisJson(_jeu(batiments: [
        {
          'id': 'x',
          's': 30,
          'c': [45, 4],
          'p': [
            [
              [45, 4],
              [45.1, 4],
            ],
          ],
        },
      ])),
      throwsFormatException,
    );
  });

  test('refuse un fichier sans version', () {
    expect(() => JeuBatiments.depuisJson(_jeu()..remove('version')), throwsFormatException);
  });
}
