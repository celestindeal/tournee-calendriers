import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tournee_calendriers/data/tournee_repository.dart';
import 'package:tournee_calendriers/models/campagne.dart';
import 'package:tournee_calendriers/models/etat_batiment.dart';
import 'package:tournee_calendriers/models/statut.dart';

void main() {
  late DatabaseFactory fabrique;
  late TourneeRepository repo;
  final date = DateTime.utc(2026, 11, 11, 10);

  EtatBatiment etat(String id, Statut s) => EtatBatiment(batimentId: id, statut: s, modifieLe: date);

  setUp(() async {
    // Une base en mémoire neuve pour chaque test (à la place d'IndexedDB).
    fabrique = newDatabaseFactoryMemory();
    repo = await TourneeRepository.ouvrir(fabrique);
  });

  tearDown(() => repo.fermer());

  test('une base neuve est vide', () async {
    expect(await repo.lireEtats(), isEmpty);
    expect(await repo.lireCampagne(), isNull);
  });

  test('enregistre puis relit un état', () async {
    await repo.enregistrer(etat('a', Statut.achete));
    await repo.enregistrer(etat('b', Statut.aRepasser));
    expect(await repo.lireEtats(), {'a': etat('a', Statut.achete), 'b': etat('b', Statut.aRepasser)});
  });

  test('les données survivent à la fermeture de l\'app (réouverture de la base)', () async {
    await repo.enregistrer(etat('a', Statut.refus));
    await repo.fermer();

    repo = await TourneeRepository.ouvrir(fabrique);
    expect(await repo.lireEtats(), {'a': etat('a', Statut.refus)});
  });

  test('un nouveau statut remplace l\'ancien', () async {
    await repo.enregistrer(etat('a', Statut.aRepasser));
    await repo.enregistrer(etat('a', Statut.achete));
    expect((await repo.lireEtats())['a']!.statut, Statut.achete);
  });

  test('repasser en « non visité » supprime l\'enregistrement', () async {
    await repo.enregistrer(etat('a', Statut.achete));
    await repo.enregistrer(etat('a', Statut.nonVisite));
    expect(await repo.lireEtats(), isEmpty);
  });

  test('remplacerTout efface l\'ancien contenu et ignore les « non visité »', () async {
    await repo.enregistrer(etat('ancien', Statut.achete));
    await repo.remplacerTout([etat('a', Statut.refus), etat('b', Statut.nonVisite)]);
    expect(await repo.lireEtats(), {'a': etat('a', Statut.refus)});
  });

  test('remplacerTout([]) remet la tournée à zéro', () async {
    await repo.enregistrer(etat('a', Statut.achete));
    await repo.remplacerTout(const []);
    expect(await repo.lireEtats(), isEmpty);
  });

  test('un enregistrement abîmé est ignoré sans bloquer les autres', () async {
    await repo.enregistrer(etat('a', Statut.achete));
    await repo.fermer();

    // Écrit directement un enregistrement invalide dans la base.
    final db = await fabrique.openDatabase(TourneeRepository.nomBase);
    await stringMapStoreFactory.store('etats').record('casse').put(db, {'s': 'statutInconnu', 't': 1});
    await db.close();

    repo = await TourneeRepository.ouvrir(fabrique);
    expect((await repo.lireEtats()).keys, ['a']);
  });

  test('dernier export et sauvegarde d\'avant import', () async {
    expect(await repo.lireDernierExport(), isNull);
    await repo.enregistrerDernierExport(date);
    expect(await repo.lireDernierExport(), date);

    expect(await repo.lireSauvegardeAvantImport(), isNull);
    await repo.enregistrerSauvegardeAvantImport('{"x": 1}');
    expect(await repo.lireSauvegardeAvantImport(), '{"x": 1}');
    await repo.effacerSauvegardeAvantImport();
    expect(await repo.lireSauvegardeAvantImport(), isNull);
  });

  test('enregistre et relit la campagne', () async {
    final c = Campagne(debut: date, versionBatiments: '2026-09-01-6c5672c1');
    await repo.enregistrerCampagne(c);
    expect(await repo.lireCampagne(), c);
  });
}
