import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/models/etat_parcelle.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/migration.dart';

void main() {
  EtatParcelle etat(String id, Statut s, int jour) =>
      EtatParcelle(parcelleId: id, statut: s, modifieLe: DateTime.utc(2026, 11, jour));

  group('le statut le plus parlant', () {
    test('le plus récent parmi acheté / refus / à repasser', () {
      final choisi = EtatParcelle.lePlusParlant([
        etat('x', Statut.aRepasser, 10),
        etat('x', Statut.achete, 12),
        etat('x', Statut.refus, 11),
      ]);
      expect(choisi.statut, Statut.achete);
    });

    test('un garage « non concerné » ne masque pas la maison « achetée »', () {
      final choisi = EtatParcelle.lePlusParlant([
        etat('x', Statut.achete, 10),
        etat('x', Statut.nonConcerne, 15), // plus récent, mais moins parlant
      ]);
      expect(choisi.statut, Statut.achete);
    });

    test('« non concerné » s\'il n\'y a rien d\'autre', () {
      expect(EtatParcelle.lePlusParlant([etat('x', Statut.nonConcerne, 10)]).statut, Statut.nonConcerne);
    });
  });

  group('report des anciens statuts sur les parcelles', () {
    const correspondances = {'maison': 'P1', 'garage': 'P1', 'voisin': 'P2'};
    const parcelles = {'P1', 'P2', 'P3'};

    test('chaque bâtiment est reporté sur sa parcelle', () {
      final r = reporterSurParcelles(
        {
          'maison': etat('maison', Statut.achete, 10),
          'garage': etat('garage', Statut.nonConcerne, 11),
          'voisin': etat('voisin', Statut.aRepasser, 12),
        },
        idsParcelles: parcelles,
        parcelleDeLAncienId: correspondances,
      );
      expect(r.reportes, 3);
      expect(r.etats.keys, unorderedEquals(['P1', 'P2']));
      expect(r.etats['P1']!.statut, Statut.achete);
      expect(r.etats['P1']!.parcelleId, 'P1');
      expect(r.etats['P1']!.modifieLe, DateTime.utc(2026, 11, 10)); // la date d'origine est gardée
      expect(r.etats['P2']!.statut, Statut.aRepasser);
    });

    test('déjà par parcelle : rien ne change', () {
      final etats = {'P1': etat('P1', Statut.refus, 10)};
      final r = reporterSurParcelles(etats, idsParcelles: parcelles, parcelleDeLAncienId: correspondances);
      expect(r.reportes, 0);
      expect(r.etats, etats);
    });

    test('un identifiant inconnu est gardé (rien n\'est jeté)', () {
      final r = reporterSurParcelles(
        {'mystere': etat('mystere', Statut.achete, 10)},
        idsParcelles: parcelles,
        parcelleDeLAncienId: correspondances,
      );
      expect(r.reportes, 0);
      expect(r.etats.keys, ['mystere']);
    });
  });
}
