import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tournee_calendriers/data/tournee_repository.dart';
import 'package:tournee_calendriers/models/memo.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';
import 'package:tournee_calendriers/synchro/changement.dart';
import 'package:tournee_calendriers/synchro/serveur_synchro.dart';
import 'package:tournee_calendriers/synchro/synchro_controller.dart';

import '../outils.dart';

/// Faux serveur PocketBase, en mémoire, avec les mêmes règles que
/// serveur/pb_migrations/1794400000_tournee.js : code d'équipe obligatoire,
/// mise à jour seulement si plus récente, rien n'est supprimé.
class FauxPocketBase {
  FauxPocketBase({this.code = 'code-equipe-123'});

  final String code;
  final tables = <String, Map<String, Map<String, Object?>>>{};
  bool enPanne = false;
  int _horloge = 0;
  final requetes = <String>[];

  String _maintenant() => '2026-11-11 10:00:${(_horloge++).toString().padLeft(6, '0')}Z';

  http.Client client() => MockClient((requete) async {
        if (enPanne) throw http.ClientException('réseau coupé');
        requetes.add('${requete.method} ${requete.url.path}');
        final codeOk = requete.headers['X-Code-Equipe'] == code;
        final morceaux = requete.url.pathSegments; // api, collections, <table>, records, [id]
        final table = morceaux[2];
        final id = morceaux.length > 4 ? morceaux[4] : null;
        final lignes = tables.putIfAbsent(table, () => {});
        Map<String, Object?> corps() => jsonDecode(requete.body) as Map<String, Object?>;
        http.Response json(Object o, [int statut = 200]) => http.Response(jsonEncode(o), statut);

        if (table == 'acces') return json({'items': codeOk ? [{'nom': 'tournee-calendriers'}] : []});
        switch ((requete.method, id)) {
          case ('GET', final id?):
            final ligne = lignes[id];
            return codeOk && ligne != null ? json(ligne) : json({'message': 'introuvable'}, 404);
          case ('PATCH', final id?):
            final ligne = lignes[id];
            final c = corps();
            final plusRecent = ligne != null &&
                (c['t'] as int) > (ligne['t'] as int) &&
                ((c['campagne'] as int?) ?? 0) >= ((ligne['campagne'] as int?) ?? 0);
            if (!codeOk || !plusRecent) return json({'message': 'introuvable'}, 404);
            lignes[id] = {...ligne, ...c, 'updated': _maintenant()};
            return json(lignes[id]!);
          case ('POST', null):
            final c = corps();
            final nouvelId = c['id'] as String;
            if (!codeOk || lignes.containsKey(nouvelId) || !RegExp(r'^[a-z0-9]{15}$').hasMatch(nouvelId)) {
              return json({'message': 'refusé'}, 400);
            }
            lignes[nouvelId] = {...c, 'updated': _maintenant()};
            return json(lignes[nouvelId]!);
          case ('GET', null):
            if (!codeOk) return json({'items': []});
            final filtre = requete.url.queryParameters['filter'] ?? '';
            final campagne = int.tryParse(RegExp(r'campagne=(\d+)').firstMatch(filtre)?[1] ?? '');
            final depuis = RegExp(r'updated>="([^"]+)"').firstMatch(filtre)?[1];
            final parPage = int.parse(requete.url.queryParameters['perPage']!);
            final page = int.parse(requete.url.queryParameters['page']!);
            final items = lignes.values
                .where((l) => campagne == null || l['campagne'] == campagne)
                .where((l) => depuis == null || (l['updated'] as String).compareTo(depuis) >= 0)
                .toList()
              ..sort((a, b) => (a['updated'] as String).compareTo(b['updated'] as String));
            return json({'items': items.skip((page - 1) * parPage).take(parPage).toList()});
        }
        return json({'message': 'non prévu'}, 400);
      });
}

/// Un téléphone : sa base, sa tournée, sa synchro, son horloge.
class Telephone {
  Telephone._(this.tournee, this.repo, this.synchro);

  final TourneeController tournee;
  final TourneeRepository repo;
  final SynchroController synchro;

  static Future<Telephone> creer(FauxPocketBase serveur, DateTime Function() horloge, {String prefixe = ''}) async {
    final (tournee, repo, _) = await controleurDeTest(horloge: horloge);
    final synchro = SynchroController(
      repo: repo,
      tournee: tournee,
      horloge: horloge,
      // Pas de minuterie pendant les tests : on synchronise à la main.
      intervalle: const Duration(days: 1),
      attenteApresModif: const Duration(days: 1),
      fabriqueServeur: (c) => ServeurPocketBase(
        adresse: c.adresse,
        code: c.code,
        prefixeTables: prefixe,
        appareil: c.appareil,
        client: serveur.client(),
      ),
    );
    await synchro.charger();
    return Telephone._(tournee, repo, synchro);
  }

  Future<void> brancher() => synchro.configurer(adresse: 'serveur-pompier.exemple.ts.net/', code: 'code-equipe-123');
}

void main() {
  late FauxPocketBase serveur;
  late DateTime maintenant;
  DateTime horloge() => maintenant;

  setUp(() {
    serveur = FauxPocketBase();
    maintenant = DateTime.utc(2026, 11, 15, 9);
  });

  void avancer([Duration d = const Duration(minutes: 1)]) => maintenant = maintenant.add(d);

  test('ce qu\'un téléphone coche arrive sur l\'autre (statuts et mémos)', () async {
    final a = await Telephone.creer(serveur, horloge);
    final b = await Telephone.creer(serveur, horloge);
    await a.brancher();
    await b.brancher();

    await a.tournee.changerStatut('a', Statut.achete);
    await a.tournee.basculerMemo('b', Memo.chien);
    expect(a.synchro.nbEnAttente, 2);
    await a.synchro.synchroniser();
    expect(a.synchro.nbEnAttente, 0);
    expect(a.synchro.etat, EtatSynchro.aJour);

    await b.synchro.synchroniser();
    expect(b.tournee.statutDe('a'), Statut.achete);
    expect(b.tournee.memosDe('b'), {Memo.chien});
    // Ce qui vient de l'autre téléphone n'est pas renvoyé.
    expect(b.synchro.nbEnAttente, 0);
  });

  test('la tournée déjà saisie est envoyée au premier branchement', () async {
    final a = await Telephone.creer(serveur, horloge);
    await a.tournee.changerStatut('a', Statut.refus);
    await a.tournee.basculerMemo('a', Memo.soir);
    await a.brancher();
    expect(a.synchro.nbEnAttente, 0);

    final b = await Telephone.creer(serveur, horloge);
    await b.brancher();
    expect(b.tournee.statutDe('a'), Statut.refus);
    expect(b.tournee.memosDe('a'), {Memo.soir});
  });

  test('deux changements hors ligne sur la même maison : le plus récent gagne partout', () async {
    final a = await Telephone.creer(serveur, horloge);
    final b = await Telephone.creer(serveur, horloge);
    await a.brancher();
    await b.brancher();

    await a.tournee.changerStatut('b', Statut.aRepasser);
    avancer();
    await b.tournee.changerStatut('b', Statut.achete); // plus récent

    await b.synchro.synchroniser();
    await a.synchro.synchroniser(); // le plus ancien arrive après : refusé
    await b.synchro.synchroniser();

    expect(a.tournee.statutDe('b'), Statut.achete);
    expect(b.tournee.statutDe('b'), Statut.achete);
    expect(a.synchro.nbEnAttente, 0);
  });

  test('remettre en « non visité » se propage aussi', () async {
    final a = await Telephone.creer(serveur, horloge);
    final b = await Telephone.creer(serveur, horloge);
    await a.brancher();
    await b.brancher();

    await a.tournee.changerStatut('a', Statut.achete);
    await a.synchro.synchroniser();
    await b.synchro.synchroniser();
    expect(b.tournee.statutDe('a'), Statut.achete);

    avancer();
    await a.tournee.changerStatut('a', Statut.nonVisite);
    await a.synchro.synchroniser();
    await b.synchro.synchroniser();
    expect(b.tournee.statutDe('a'), Statut.nonVisite);
    // Et l'ancien « acheté » ne revient pas sur le premier téléphone.
    await a.synchro.synchroniser();
    expect(a.tournee.statutDe('a'), Statut.nonVisite);
  });

  test('sans réseau : les changements attendent, puis partent au retour du réseau', () async {
    final a = await Telephone.creer(serveur, horloge);
    await a.brancher();
    serveur.enPanne = true;

    await a.tournee.changerStatut('a', Statut.achete);
    await a.synchro.synchroniser();
    expect(a.synchro.etat, EtatSynchro.horsLigne);
    expect(a.synchro.nbEnAttente, 1);

    serveur.enPanne = false;
    await a.synchro.synchroniser();
    expect(a.synchro.etat, EtatSynchro.aJour);
    expect(a.synchro.nbEnAttente, 0);
    expect(serveur.tables['statuts']!.values.single['statut'], 'achete');
  });

  test('la file d\'attente survit à la fermeture de l\'app', () async {
    final a = await Telephone.creer(serveur, horloge);
    await a.brancher();
    serveur.enPanne = true;
    await a.tournee.changerStatut('a', Statut.achete);
    await Future<void>.delayed(Duration.zero);

    // « Réouverture » : nouvelle synchro sur la même base.
    final synchro2 = SynchroController(
      repo: a.repo,
      tournee: a.tournee,
      intervalle: const Duration(days: 1),
      fabriqueServeur: (c) => ServeurPocketBase(
        adresse: c.adresse,
        code: c.code,
        prefixeTables: '',
        appareil: c.appareil,
        client: serveur.client(),
      ),
    );
    await synchro2.charger();
    expect(synchro2.active, isTrue);
    expect(synchro2.nbEnAttente, 1);
    serveur.enPanne = false;
    await synchro2.synchroniser();
    expect(synchro2.nbEnAttente, 0);
    synchro2.dispose();
  });

  test('mauvais code : refusé avec un message clair', () async {
    final a = await Telephone.creer(serveur, horloge);
    await expectLater(
      a.synchro.configurer(adresse: 'serveur-pompier.exemple.ts.net', code: 'mauvais-code-000'),
      throwsA(isA<ErreurSynchro>().having((e) => e.message, 'message', 'Code d\'équipe refusé.')),
    );
    expect(a.synchro.active, isFalse);
  });

  test('l\'environnement de test écrit dans ses propres tables', () async {
    final a = await Telephone.creer(serveur, horloge, prefixe: 'test_');
    await a.brancher();
    await a.tournee.changerStatut('a', Statut.achete);
    await a.synchro.synchroniser();
    expect(serveur.tables['test_statuts'], hasLength(1));
    expect(serveur.tables['statuts'] ?? {}, isEmpty);
  });

  test('arrêter la synchronisation ne touche pas aux maisons', () async {
    final a = await Telephone.creer(serveur, horloge);
    await a.brancher();
    await a.tournee.changerStatut('a', Statut.achete);
    await a.synchro.desactiver();
    expect(a.synchro.active, isFalse);
    expect(a.synchro.nbEnAttente, 0);
    expect(a.tournee.statutDe('a'), Statut.achete);
  });

  group('identifiants sur le serveur', () {
    test('15 caractères a-z0-9, toujours les mêmes', () {
      String id(String parcelle) => ServeurPocketBase.idEnregistrement(
            Changement.statut(parcelleId: parcelle, campagne: 2026, statut: Statut.achete, t: 1),
          );
      expect(id('422340000A0123'), 's422340000a0123');
      expect(id('bat-u054gtzex'), 'sxcbatu054gtzex');
      expect(id('a'), 'sx1a00000000000');
      for (final i in ['422340000A0123', 'bat-u054gtzex', 'a']) {
        expect(id(i), matches(RegExp(r'^[a-z0-9]{15}$')));
      }
      expect(
        ServeurPocketBase.idEnregistrement(Changement.memos(parcelleId: '422340000A0123', memos: {}, t: 1)),
        'm422340000a0123',
      );
    });

    test('adresse complétée en https', () {
      expect(ServeurPocketBase.normaliserAdresse(' serveur.ts.net/ '), 'https://serveur.ts.net');
      expect(ServeurPocketBase.normaliserAdresse('http://192.168.1.20:8090'), 'http://192.168.1.20:8090');
    });
  });
}
