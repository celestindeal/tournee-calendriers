import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/models/statut.dart';

void main() {
  test('les noms stockés ne changent pas (sinon les données de l\'iPhone deviennent illisibles)', () {
    expect(
      Statut.values.map((s) => s.name),
      ['nonVisite', 'achete', 'aRepasser', 'refus', 'nonConcerne'],
    );
  });

  test('acheté et refus comptent comme faits, pas les autres', () {
    expect(Statut.values.where((s) => s.estFait), [Statut.achete, Statut.refus]);
  });

  test('depuisNom retrouve un statut ou renvoie null', () {
    expect(Statut.depuisNom('aRepasser'), Statut.aRepasser);
    expect(Statut.depuisNom('inconnu'), isNull);
  });
}
