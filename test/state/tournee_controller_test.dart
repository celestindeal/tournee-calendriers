import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tournee_calendriers/data/export_service.dart';
import 'package:tournee_calendriers/data/tournee_repository.dart';
import 'package:tournee_calendriers/models/campagne.dart';
import 'package:tournee_calendriers/models/etat_parcelle.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';

import '../outils.dart';

void main() {
  final maintenant = DateTime.utc(2026, 11, 15, 9, 30);

  group('passage du suivi par bâtiment au suivi par parcelle', () {
    final avant = DateTime.utc(2026, 11, 11, 15);
    EtatParcelle ancien(String id, Statut s, int minute) =>
        EtatParcelle(parcelleId: id, statut: s, modifieLe: avant.add(Duration(minutes: minute)));

    test('au démarrage, les maisons déjà cochées sont reportées sur leur parcelle', () async {
      final fabrique = newDatabaseFactoryMemory();
      // Base telle que laissée par l'ancienne version (identifiants de bâtiments).
      final repo0 = await TourneeRepository.ouvrir(fabrique);
      await repo0.remplacerTout([
        ancien('vieux-a1', Statut.achete, 0), // maison de la parcelle « a »
        ancien('vieux-a2', Statut.nonConcerne, 5), // son garage
        ancien('vieux-b1', Statut.aRepasser, 10),
      ]);
      await repo0.fermer();

      final repo = await TourneeRepository.ouvrir(fabrique);
      final c = TourneeController(repo: repo, jeu: jeuDeTest(), horloge: () => maintenant);
      await c.charger();

      expect(c.statutsReportes, 3);
      expect(c.statutDe('a'), Statut.achete);
      expect(c.statutDe('b'), Statut.aRepasser);
      expect(c.avancement.resume, '1 / 3 faits (33 %) – 1 à repasser');
      // Enregistré par parcelle, anciens identifiants retirés.
      expect((await repo.lireEtats()).keys, unorderedEquals(['a', 'b']));
      // Copie de sécurité de l'ancien suivi.
      expect(await repo.lireSauvegardeAvantParcelles(), contains('vieux-a2'));

      // Au démarrage suivant, plus rien à reporter.
      final c2 = TourneeController(repo: repo, jeu: jeuDeTest());
      await c2.charger();
      expect(c2.statutsReportes, 0);
      expect(c2.statutDe('a'), Statut.achete);
    });

    test('un export fait avant le passage aux parcelles s\'importe sur les parcelles', () async {
      final ancienExport = ExportService.exporter(
        etats: [ancien('vieux-a1', Statut.refus, 0), ancien('vieux-b1', Statut.achete, 1), ancien('disparu', Statut.achete, 2)],
        versionCarte: '2026-09-01-6c5672c1',
        maintenant: avant,
      );
      final (c, _, _) = await controleurDeTest(horloge: () => maintenant);
      final r = c.lireImport(ancienExport);
      expect(r.etats.map((e) => e.parcelleId), unorderedEquals(['a', 'b']));
      expect(r.ignores, 1);
      await c.importer(r);
      expect(c.statutDe('a'), Statut.refus);
      expect(c.statutDe('b'), Statut.achete);
    });
  });

  test('au premier lancement : tout est non visité et la campagne est créée', () async {
    final (c, repo, _) = await controleurDeTest(horloge: () => maintenant);
    expect(c.avancement.resume, '0 / 3 faits (0 %) – 0 à repasser');
    expect(c.campagne, Campagne(debut: maintenant, versionCarte: 'test-1'));
    expect(await repo.lireCampagne(), c.campagne);
  });

  test('changer un statut met à jour l\'écran et l\'enregistre', () async {
    final (c, repo, _) = await controleurDeTest(horloge: () => maintenant);
    var notifications = 0;
    c.addListener(() => notifications++);

    final ok = await c.changerStatut('a', Statut.achete);

    expect(ok, isTrue);
    expect(c.statutDe('a'), Statut.achete);
    expect(notifications, greaterThan(0));
    expect(c.avancement.resume, '1 / 3 faits (33 %) – 0 à repasser');
    final enBase = await repo.lireEtats();
    expect(enBase['a']!.statut, Statut.achete);
    expect(enBase['a']!.modifieLe, maintenant);
  });

  test('l\'écran change avant même la fin de l\'écriture (instantané)', () async {
    final (c, _, _) = await controleurDeTest();
    final ecriture = c.changerStatut('b', Statut.aRepasser);
    expect(c.statutDe('b'), Statut.aRepasser);
    await ecriture;
  });

  test('les statuts sont retrouvés après redémarrage de l\'app', () async {
    final (c, repo, fabrique) = await controleurDeTest();
    await c.changerStatut('a', Statut.refus);
    await c.changerStatut('b', Statut.nonConcerne);
    await repo.fermer();

    final repo2 = await TourneeRepository.ouvrir(fabrique);
    final c2 = TourneeController(repo: repo2, jeu: jeuDeTest());
    await c2.charger();
    expect(c2.statutDe('a'), Statut.refus);
    expect(c2.statutDe('b'), Statut.nonConcerne);
    expect(c2.avancement.resume, '1 / 2 faits (50 %) – 0 à repasser');
  });

  test('remettre en non visité efface le statut', () async {
    final (c, repo, _) = await controleurDeTest();
    await c.changerStatut('a', Statut.achete);
    await c.changerStatut('a', Statut.nonVisite);
    expect(c.statutDe('a'), Statut.nonVisite);
    expect(await repo.lireEtats(), isEmpty);
  });

  test('si l\'enregistrement échoue : ancien statut remis et message d\'erreur', () async {
    final (c, repo, _) = await controleurDeTest();
    await c.changerStatut('a', Statut.aRepasser);
    await repo.fermer(); // simule une base devenue inaccessible

    final ok = await c.changerStatut('a', Statut.achete);

    expect(ok, isFalse);
    expect(c.statutDe('a'), Statut.aRepasser);
    expect(c.derniereErreur, isNotNull);
    c.effacerErreur();
    expect(c.derniereErreur, isNull);
  });

  test('un bâtiment inconnu est ignoré', () async {
    final (c, _, _) = await controleurDeTest();
    expect(await c.changerStatut('inexistant', Statut.achete), isFalse);
    c.selectionner('inexistant');
    expect(c.selection, isNull);
  });

  test('sélection d\'un bâtiment', () async {
    final (c, _, _) = await controleurDeTest();
    c.selectionner('b');
    expect(c.selection!.adresse, '13 Rue de l’Avenir');
    c.selectionner(null);
    expect(c.selection, isNull);
  });

  group('export / import (F8)', () {
    test('export puis import dans une autre app : mêmes statuts', () async {
      final (source, _, _) = await controleurDeTest(horloge: () => maintenant);
      await source.changerStatut('a', Statut.achete);
      await source.changerStatut('b', Statut.aRepasser);
      final fichier = source.contenuExport(maintenant);

      final (cible, repoCible, _) = await controleurDeTest(horloge: () => maintenant);
      await cible.changerStatut('c', Statut.refus);
      await cible.importer(cible.lireImport(fichier));

      expect(cible.statutDe('a'), Statut.achete);
      expect(cible.statutDe('b'), Statut.aRepasser);
      expect(cible.statutDe('c'), Statut.nonVisite);
      expect((await repoCible.lireEtats()).keys, unorderedEquals(['a', 'b']));
      expect(cible.peutAnnulerImport, isTrue);
    });

    test('annuler l\'import remet exactement la tournée d\'avant', () async {
      final (c, repo, _) = await controleurDeTest(horloge: () => maintenant);
      await c.changerStatut('c', Statut.refus);
      final (autre, _, _) = await controleurDeTest(horloge: () => maintenant);
      await autre.changerStatut('a', Statut.achete);

      await c.importer(c.lireImport(autre.contenuExport(maintenant)));
      expect(c.statutDe('c'), Statut.nonVisite);

      await c.annulerDernierImport();
      expect(c.statutDe('c'), Statut.refus);
      expect(c.statutDe('a'), Statut.nonVisite);
      expect(c.peutAnnulerImport, isFalse);
      expect(await repo.lireSauvegardeAvantImport(), isNull);
    });

    test('la possibilité d\'annuler survit au redémarrage', () async {
      final (c, repo, fabrique) = await controleurDeTest(horloge: () => maintenant);
      await c.importer(c.lireImport(c.contenuExport(maintenant)));
      await repo.fermer();

      final c2 = TourneeController(repo: await TourneeRepository.ouvrir(fabrique), jeu: jeuDeTest());
      await c2.charger();
      expect(c2.peutAnnulerImport, isTrue);
    });

    test('la date du dernier export est retenue', () async {
      final (c, repo, fabrique) = await controleurDeTest();
      expect(c.dernierExport, isNull);
      await c.noterExport(maintenant);
      expect(c.dernierExport, maintenant);
      await repo.fermer();

      final c2 = TourneeController(repo: await TourneeRepository.ouvrir(fabrique), jeu: jeuDeTest());
      await c2.charger();
      expect(c2.dernierExport, maintenant);
    });
  });

  test('un état d\'un ancien jeu de bâtiments est gardé mais pas compté', () async {
    final (c0, repo, fabrique) = await controleurDeTest();
    await c0.changerStatut('a', Statut.achete);
    await repo.fermer();

    // Le bâtiment « a » n'existe plus dans le nouveau jeu.
    final repo2 = await TourneeRepository.ouvrir(fabrique);
    final c = TourneeController(repo: repo2, jeu: jeuDeTest().copieSans('a'));
    await c.charger();
    expect(c.avancement.faits, 0);
    expect(c.avancement.nbParcelles, 2);
    expect((await repo2.lireEtats()).keys, ['a']);
  });
}
