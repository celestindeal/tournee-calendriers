import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/models/jeu_parcelles.dart';

List<List<num>> _triangle(num lat) => [
      [lat, 4.3796],
      [lat + 0.0001, 4.3797],
      [lat, 4.3795],
    ];

Map<String, dynamic> _parcelle(String id, {String? adresse, List<String> anciens = const []}) => {
      'id': id,
      'a': ?adresse,
      's': 944,
      'c': [45.514197, 4.379658],
      'p': [_triangle(45.5141)],
      'b': [_triangle(45.51412)],
      'anciens': anciens,
      'co': '42234',
    };

Map<String, dynamic> _jeu({List<Map<String, dynamic>>? parcelles, Object? format = 3}) => {
      'format': format,
      'version': '2026-09-01-abcd1234',
      'communes': [
        {
          'insee': '42234',
          'nom': 'Saint-Héand',
          'bbox': [
            [45.50, 4.34],
            [45.56, 4.42],
          ],
        },
        {
          'insee': '42010',
          'nom': 'Aveizieux',
          'bbox': [
            [45.55, 4.34],
            [45.58, 4.40],
          ],
        },
      ],
      'sources': {'cadastre': 'Cadastre', 'adresses': 'BAN'},
      'centre': [45.53, 4.38],
      'bbox': [
        [45.50, 4.34],
        [45.56, 4.42],
      ],
      'parcelles': parcelles ??
          [
            _parcelle('422340000B1353', adresse: '7 Rue Jacques Prévert', anciens: ['u054gtt5m', 'u054gtt5q']),
            _parcelle('bat-u054fumme', anciens: ['u054fumme']),
          ],
    };

void main() {
  test('lit le format produit par tool/preparer_donnees.dart', () {
    final jeu = JeuParcelles.depuisJson(_jeu());
    expect(jeu.version, '2026-09-01-abcd1234');
    expect(jeu.communes.map((c) => c.nom), ['Saint-Héand', 'Aveizieux']);
    expect(jeu.communes.last.nordEst.latitude, 45.58);
    expect(jeu.nomCommune('42010'), 'Aveizieux');
    expect(jeu.nomCommune('99999'), isNull);
    expect(jeu.parcelles.first.codeInsee, '42234');
    expect(jeu.sources, ['Cadastre', 'BAN']);
    expect(jeu.parcelles, hasLength(2));

    final p = jeu.parcelles.first;
    expect(p.id, '422340000B1353');
    expect(p.adresse, '7 Rue Jacques Prévert');
    expect(p.surfaceM2, 944.0);
    expect(p.contours.single, hasLength(3));
    expect(p.batiments.single, hasLength(3));
    expect(jeu.parcelles.last.adresse, isNull);
  });

  test('correspondance ancien bâtiment → parcelle', () {
    final jeu = JeuParcelles.depuisJson(_jeu());
    expect(jeu.parcelleDeLAncienId, {
      'u054gtt5m': '422340000B1353',
      'u054gtt5q': '422340000B1353',
      'u054fumme': 'bat-u054fumme',
    });
  });

  test('refuse les anciens formats (par bâtiment, une seule commune)', () {
    expect(() => JeuParcelles.depuisJson(_jeu(format: null)), throwsFormatException);
    expect(() => JeuParcelles.depuisJson(_jeu(format: 2)), throwsFormatException);
  });

  test('refuse un identifiant en double', () {
    final p = _parcelle('x');
    expect(() => JeuParcelles.depuisJson(_jeu(parcelles: [p, p])), throwsFormatException);
  });

  test('refuse une parcelle sans bâtiment', () {
    expect(
      () => JeuParcelles.depuisJson(_jeu(parcelles: [_parcelle('x')..['b'] = []])),
      throwsFormatException,
    );
  });

  test('refuse un fichier sans version', () {
    expect(() => JeuParcelles.depuisJson(_jeu()..remove('version')), throwsFormatException);
  });
}
