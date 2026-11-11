import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/models/campagne.dart';
import 'package:tournee_calendriers/models/etat_batiment.dart';
import 'package:tournee_calendriers/models/statut.dart';

void main() {
  final date = DateTime.utc(2026, 11, 11, 18, 32);

  group('EtatBatiment', () {
    test('aller-retour vers le stockage', () {
      final etat = EtatBatiment(batimentId: 'u054gtt5m', statut: Statut.achete, modifieLe: date);
      final stocke = etat.versStockage();
      expect(stocke, {'s': 'achete', 't': date.millisecondsSinceEpoch});
      expect(EtatBatiment.depuisStockage('u054gtt5m', stocke), etat);
    });

    test('un enregistrement illisible donne null au lieu de planter', () {
      expect(EtatBatiment.depuisStockage('x', {'s': 'inconnu', 't': 1}), isNull);
      expect(EtatBatiment.depuisStockage('x', {'s': 'achete'}), isNull);
      expect(EtatBatiment.depuisStockage('x', {'t': 1}), isNull);
    });
  });

  group('Campagne', () {
    test('aller-retour vers le stockage', () {
      final c = Campagne(debut: date, versionBatiments: '2026-09-01-6c5672c1');
      expect(Campagne.depuisStockage(c.versStockage()), c);
    });

    test('un enregistrement illisible donne null', () {
      expect(Campagne.depuisStockage({'debut': 'hier'}), isNull);
    });
  });
}
