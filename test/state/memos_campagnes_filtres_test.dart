import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/data/export_service.dart';
import 'package:tournee_calendriers/data/tournee_repository.dart';
import 'package:tournee_calendriers/models/etat_parcelle.dart';
import 'package:tournee_calendriers/models/filtre.dart';
import 'package:tournee_calendriers/models/memo.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';

import '../outils.dart';

void main() {
  var maintenant = DateTime.utc(2026, 11, 15, 9, 30);
  setUp(() => maintenant = DateTime.utc(2026, 11, 15, 9, 30));

  group('mémos', () {
    test('les noms stockés ne changent pas (sinon les mémos de l\'iPhone sont perdus)', () {
      expect(Memo.values.map((m) => m.name), [
        'chien', 'pasDeDemarchage', 'motLaisse', 'matin', 'midi', 'soir', 'weekend', //
        'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
      ]);
    });

    test('cocher, décocher, et retrouver après redémarrage', () async {
      final (c, repo, fabrique) = await controleurDeTest(horloge: () => maintenant);
      await c.basculerMemo('a', Memo.chien);
      await c.basculerMemo('a', Memo.soir);
      await c.basculerMemo('a', Memo.jeudi);
      await c.basculerMemo('a', Memo.soir); // décoché
      expect(c.memosDe('a'), {Memo.chien, Memo.jeudi});
      await repo.fermer();

      final c2 = TourneeController(repo: await TourneeRepository.ouvrir(fabrique), jeu: jeuDeTest());
      await c2.charger();
      expect(c2.memosDe('a'), {Memo.chien, Memo.jeudi});
      expect(c2.memosDe('b'), isEmpty);
    });

    test('export puis import : statuts et mémos', () async {
      final (source, _, _) = await controleurDeTest(horloge: () => maintenant);
      await source.changerStatut('a', Statut.aRepasser);
      await source.basculerMemo('a', Memo.chien);
      final fichier = source.contenuExport(maintenant);

      final (cible, _, _) = await controleurDeTest(horloge: () => maintenant);
      await cible.basculerMemo('b', Memo.motLaisse);
      await cible.importer(cible.lireImport(fichier));
      expect(cible.statutDe('a'), Statut.aRepasser);
      expect(cible.memosDe('a'), {Memo.chien});
      expect(cible.memosDe('b'), isEmpty); // remplacés par ceux du fichier

      await cible.annulerDernierImport();
      expect(cible.memosDe('b'), {Memo.motLaisse});
      expect(cible.memosDe('a'), isEmpty);
    });

    test('un export fait avant les mémos ne les efface pas', () async {
      final ancienExport = ExportService.exporter(
        etats: [EtatParcelle(parcelleId: 'a', statut: Statut.achete, modifieLe: maintenant)],
        versionCarte: 'test-1',
        maintenant: maintenant,
      ).replaceFirst(RegExp(r',\s*"memos": \[\]'), '');
      expect(ancienExport, isNot(contains('memos')));

      final (c, _, _) = await controleurDeTest(horloge: () => maintenant);
      await c.basculerMemo('b', Memo.chien);
      await c.importer(c.lireImport(ancienExport));
      expect(c.statutDe('a'), Statut.achete);
      expect(c.memosDe('b'), {Memo.chien});
    });
  });

  group('campagnes', () {
    test('la première campagne prend l\'année en cours', () async {
      final (c, _, _) = await controleurDeTest(horloge: () => maintenant);
      expect(c.campagne!.annee, 2026);
      expect(c.archives, isEmpty);
    });

    test('nouvelle campagne : archive, remet à zéro, garde les mémos', () async {
      final (c, repo, fabrique) = await controleurDeTest(horloge: () => maintenant);
      await c.changerStatut('a', Statut.achete);
      await c.changerStatut('b', Statut.refus);
      await c.basculerMemo('a', Memo.chien);

      maintenant = DateTime.utc(2027, 11, 10);
      await c.nouvelleCampagne(2027);

      expect(c.campagne!.annee, 2027);
      expect(c.statutDe('a'), Statut.nonVisite);
      expect(c.avancement.faits, 0);
      expect(c.memosDe('a'), {Memo.chien});
      expect(c.statutPrecedent('a'), (annee: 2026, statut: Statut.achete));
      expect(c.statutPrecedent('b'), (annee: 2026, statut: Statut.refus));
      expect(c.statutPrecedent('c'), isNull);
      expect(c.archives.single.nombre(Statut.achete), 1);

      // Tout est retrouvé après redémarrage.
      await repo.fermer();
      final c2 = TourneeController(repo: await TourneeRepository.ouvrir(fabrique), jeu: jeuDeTest());
      await c2.charger();
      expect(c2.campagne!.annee, 2027);
      expect(c2.statutPrecedent('a')?.statut, Statut.achete);
      expect(c2.memosDe('a'), {Memo.chien});
    });

    test('seules les 2 dernières campagnes sont gardées', () async {
      final (c, _, _) = await controleurDeTest(horloge: () => maintenant);
      for (final annee in [2027, 2028, 2029]) {
        await c.changerStatut('a', Statut.achete);
        await c.nouvelleCampagne(annee);
      }
      expect(c.archives.map((a) => a.annee), [2028, 2027]);
    });

    test('une nouvelle campagne ne peut pas remonter le temps', () async {
      final (c, _, _) = await controleurDeTest(horloge: () => maintenant);
      expect(() => c.nouvelleCampagne(2026), throwsArgumentError);
    });

    test('après une nouvelle campagne, on ne peut plus « annuler l\'import » de l\'ancienne', () async {
      final (c, _, _) = await controleurDeTest(horloge: () => maintenant);
      await c.importer(c.lireImport(c.contenuExport(maintenant)));
      expect(c.peutAnnulerImport, isTrue);
      await c.nouvelleCampagne(2027);
      expect(c.peutAnnulerImport, isFalse);
    });
  });

  group('filtres', () {
    test('« À repasser » et « Non visitées »', () async {
      final (c, _, _) = await controleurDeTest(horloge: () => maintenant);
      await c.changerStatut('a', Statut.aRepasser);
      await c.changerStatut('b', Statut.achete);

      expect(['a', 'b', 'c'].where(c.estVisible), ['a', 'b', 'c']);
      c.changerFiltre(Filtre.aRepasser);
      expect(['a', 'b', 'c'].where(c.estVisible), ['a']);
      c.changerFiltre(Filtre.nonVisitees);
      expect(['a', 'b', 'c'].where(c.estVisible), ['c']);
    });

    test('le panneau se ferme si la maison sélectionnée est masquée par le filtre', () async {
      final (c, _, _) = await controleurDeTest(horloge: () => maintenant);
      await c.changerStatut('b', Statut.achete);
      c.selectionner('b');
      c.changerFiltre(Filtre.aRepasser);
      expect(c.selection, isNull);
    });
  });
}
