import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/models/avancement.dart';
import 'package:tournee_calendriers/models/statut.dart';

void main() {
  test('exemple du cahier des charges : « 132 / 480 faits (27 %) – 45 à repasser »', () {
    final a = Avancement.calculer(
      nbBatiments: 500,
      statuts: [
        ...List.filled(100, Statut.achete),
        ...List.filled(32, Statut.refus),
        ...List.filled(45, Statut.aRepasser),
        ...List.filled(20, Statut.nonConcerne),
      ],
    );
    expect(a.total, 480); // 500 − 20 non concernés
    expect(a.faits, 132); // achetés + refus
    expect(a.nonVisites, 303);
    expect(a.pourcentage, 27); // 27,5 % arrondi en dessous
    expect(a.resume, '132 / 480 faits (27 %) – 45 à repasser');
  });

  test('au début de la tournée, tout est à 0', () {
    final a = Avancement.calculer(nbBatiments: 2457, statuts: const []);
    expect(a.resume, '0 / 2457 faits (0 %) – 0 à repasser');
    expect(a.nonVisites, 2457);
  });

  test('pas de division par zéro si tout est non concerné', () {
    final a = Avancement.calculer(nbBatiments: 2, statuts: [Statut.nonConcerne, Statut.nonConcerne]);
    expect(a.total, 0);
    expect(a.pourcentage, 0);
  });

  test('100 % seulement quand tout est vraiment fait', () {
    final presque = Avancement.calculer(nbBatiments: 1000, statuts: List.filled(999, Statut.achete));
    expect(presque.pourcentage, 99);
    final fini = Avancement.calculer(nbBatiments: 1000, statuts: List.filled(1000, Statut.refus));
    expect(fini.pourcentage, 100);
  });
}
