import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tournee_calendriers/models/parcelle.dart';
import 'package:tournee_calendriers/state/listes.dart';

Parcelle _p(String id, String? adresse, {String insee = '42234'}) => Parcelle(
      id: id,
      adresse: adresse,
      codeInsee: insee,
      surfaceM2: 100,
      centre: const LatLng(45.5, 4.38),
      contours: const [
        [LatLng(45.5, 4.38), LatLng(45.5001, 4.38), LatLng(45.5, 4.3801)],
      ],
      batiments: const [
        [LatLng(45.5, 4.38), LatLng(45.5001, 4.38), LatLng(45.5, 4.3801)],
      ],
    );

void main() {
  group('découpage des adresses', () {
    test('numéro, complément et lieu-dit', () {
      expect(decouperAdresse('12 Rue Apollo'), (numero: 12, rue: 'Rue Apollo'));
      expect(decouperAdresse('8 bis Place d\'Eculieu'), (numero: 8, rue: 'Place d\'Eculieu'));
      expect(decouperAdresse('326 Chemin d’Albigneux, Le Grand Champ'), (numero: 326, rue: 'Chemin d’Albigneux'));
      expect(decouperAdresse('12 Rue Apollo / 14 Rue Apollo'), (numero: 12, rue: 'Rue Apollo'));
      expect(decouperAdresse('3 Impasse X / 5 Impasse X (+2)'), (numero: 3, rue: 'Impasse X'));
      expect(decouperAdresse('Hameau les Atheux'), (numero: 0, rue: 'Hameau les Atheux'));
      expect(decouperAdresse(null), (numero: 0, rue: rueInconnue));
    });
  });

  test('rangement par commune, rue (sans accents), puis numéro', () {
    final groupes = grouperParRue(
      [
        _p('1', '12 Rue de l\'Église'),
        _p('2', '2 Rue de l\'Église'),
        _p('3', '5 Allée des Pins'),
        _p('4', null),
        _p('5', '1 Rue Basse', insee: '42097'),
        _p('6', '10 Rue de l\'Eglise'), // sans accent : même ordre que « Église »
      ],
      ordreCommunes: ['42234', '42097'],
    );
    expect(groupes.map((g) => '${g.insee} ${g.rue}'), [
      '42234 Allée des Pins',
      '42234 Rue de l\'Eglise',
      '42234 Rue de l\'Église',
      '42234 $rueInconnue', // les adresses inconnues à la fin de leur commune
      '42097 Rue Basse',
    ]);
    expect(groupes[2].parcelles.map((p) => p.id), ['2', '1']); // 2 avant 12
  });
}
