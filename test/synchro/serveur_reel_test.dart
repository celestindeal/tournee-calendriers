// Essai contre un vrai serveur PocketBase (pas lancé avec les autres tests).
//
// Lancer un serveur local avec serveur/pb_hooks, puis :
//   flutter test test/synchro/serveur_reel_test.dart \
//     --dart-define=POCKETBASE=http://127.0.0.1:8090 --dart-define=CODE=essai-local-123456
@Tags(['serveur'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tournee_calendriers/models/memo.dart';
import 'package:tournee_calendriers/models/statut.dart';
import 'package:tournee_calendriers/state/tournee_controller.dart';
import 'package:tournee_calendriers/synchro/serveur_synchro.dart';
import 'package:tournee_calendriers/synchro/synchro_controller.dart';

import '../outils.dart';

const _adresse = String.fromEnvironment('POCKETBASE');
const _code = String.fromEnvironment('CODE');

Future<(TourneeController, SynchroController)> _telephone(DateTime Function() horloge, String prefixe) async {
  final (tournee, repo, _) = await controleurDeTest(horloge: horloge);
  final synchro = SynchroController(
    repo: repo,
    tournee: tournee,
    horloge: horloge,
    intervalle: const Duration(days: 1),
    attenteApresModif: const Duration(days: 1),
    fabriqueServeur: (c) => ServeurPocketBase(
      adresse: c.adresse,
      code: c.code,
      prefixeTables: prefixe,
      appareil: c.appareil,
      client: http.Client(),
    ),
  );
  await synchro.charger();
  return (tournee, synchro);
}

void main() {
  test('deux téléphones se synchronisent par le vrai serveur', () async {
    // Préfixe de tables de test, et une « campagne » unique pour ne pas
    // retrouver les essais précédents.
    final campagneEssai = DateTime.now().millisecondsSinceEpoch;
    var maintenant = DateTime.now().toUtc();
    DateTime horloge() => maintenant;

    final (tourneeA, synchroA) = await _telephone(horloge, 'test_');
    final (tourneeB, synchroB) = await _telephone(horloge, 'test_');
    await tourneeA.nouvelleCampagne(campagneEssai);
    await tourneeB.nouvelleCampagne(campagneEssai);

    await expectLater(
      synchroA.configurer(adresse: _adresse, code: 'mauvais-code-0000'),
      throwsA(isA<ErreurSynchro>()),
    );
    await synchroA.configurer(adresse: _adresse, code: _code);
    await synchroB.configurer(adresse: _adresse, code: _code);
    expect(synchroA.etat, EtatSynchro.aJour, reason: synchroA.message);

    await tourneeA.changerStatut('a', Statut.achete);
    await tourneeA.basculerMemo('b', Memo.chien);
    await synchroA.synchroniser();
    expect(synchroA.nbEnAttente, 0, reason: synchroA.message);

    await synchroB.synchroniser();
    expect(tourneeB.statutDe('a'), Statut.achete);
    expect(tourneeB.memosDe('b'), contains(Memo.chien));

    // Conflit : B modifie plus tard, A plus tôt mais envoie après.
    maintenant = maintenant.add(const Duration(seconds: 1));
    await tourneeA.changerStatut('a', Statut.refus);
    maintenant = maintenant.add(const Duration(seconds: 1));
    await tourneeB.changerStatut('a', Statut.aRepasser);
    await synchroB.synchroniser();
    await synchroA.synchroniser();
    expect(tourneeA.statutDe('a'), Statut.aRepasser);
    expect(synchroA.nbEnAttente, 0);
  }, skip: _adresse.isEmpty ? 'pas de serveur indiqué (--dart-define=POCKETBASE=…)' : null);
}
