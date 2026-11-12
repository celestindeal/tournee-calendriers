import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'changement.dart';

/// Problème de synchronisation à montrer à l'utilisateur.
class ErreurSynchro implements Exception {
  const ErreurSynchro(this.message, {this.horsLigne = false});

  final String message;

  /// Pas de réseau (ou serveur injoignable) : on réessaiera plus tard.
  final bool horsLigne;

  @override
  String toString() => message;
}

/// Ce que l'app attend du serveur (remplacé par un faux serveur dans les tests).
abstract class ServeurSynchro {
  /// Vérifie que le serveur répond et accepte le code d'équipe.
  /// Lève [ErreurSynchro] sinon.
  Future<void> verifierAcces();

  /// Envoie un changement. Ne fait rien si le serveur a déjà plus récent.
  /// Lève [ErreurSynchro] si l'envoi n'a pas pu se faire (à réessayer).
  Future<void> envoyer(Changement changement);

  /// Changements enregistrés sur le serveur depuis [depuis] (curseur renvoyé
  /// par l'appel précédent, `null` = tout). Pour les statuts, seulement ceux
  /// de [campagne].
  Future<({List<Changement> changements, String? curseur})> recevoir(
    TypeChangement type, {
    int? campagne,
    String? depuis,
  });
}

/// Serveur PocketBase de la Raspberry Pi (tables créées par
/// serveur/pb_migrations/1794400000_tournee.js).
class ServeurPocketBase implements ServeurSynchro {
  ServeurPocketBase({
    required String adresse,
    required this.cle,
    required this.prefixeTables,
    required this.appareil,
    http.Client? client,
    this.delai = const Duration(seconds: 15),
  }) : adresse = normaliserAdresse(adresse),
       _client = client ?? http.Client();

  final String adresse;
  final String cle;

  /// '' en production, 'test_' pour l'environnement de test.
  final String prefixeTables;

  /// Identifiant aléatoire du téléphone (aide au diagnostic, rien de personnel).
  final String appareil;
  final Duration delai;
  final http.Client _client;

  static const _parPage = 500;

  /// « serveur.ts.net/ » → « https://serveur.ts.net ».
  static String normaliserAdresse(String adresse) {
    var a = adresse.trim();
    if (!a.contains('://')) a = 'https://$a';
    while (a.endsWith('/')) {
      a = a.substring(0, a.length - 1);
    }
    return a;
  }

  Map<String, String> get _entetes => {'X-Cle-Synchro': cle, 'Content-Type': 'application/json'};

  String _table(TypeChangement type) => '$prefixeTables${type == TypeChangement.statut ? 'statuts' : 'memos'}';

  Uri _uri(String chemin, [Map<String, String>? parametres]) =>
      Uri.parse('$adresse$chemin').replace(queryParameters: parametres);

  Future<http.Response> _appel(Future<http.Response> Function() requete) async {
    try {
      return await requete().timeout(delai);
    } on TimeoutException {
      throw const ErreurSynchro('Le serveur ne répond pas.', horsLigne: true);
    } on http.ClientException {
      throw const ErreurSynchro('Pas de réseau, ou serveur injoignable.', horsLigne: true);
    }
  }

  Never _echec(String quoi, http.Response r) => throw ErreurSynchro('$quoi : le serveur a répondu ${r.statusCode}.');

  @override
  Future<void> verifierAcces() async {
    final r = await _appel(
      () => _client.get(_uri('/api/collections/acces/records', {'perPage': '1'}), headers: _entetes),
    );
    if (r.statusCode == 404) {
      throw const ErreurSynchro('Ce serveur n\'est pas celui de la tournée (adresse à vérifier).');
    }
    if (r.statusCode != 200) _echec('Vérification', r);
    final items = (jsonDecode(r.body) as Map<String, Object?>)['items'];
    if (items is! List || items.isEmpty) throw const ErreurSynchro('Code d\'équipe refusé.');
  }

  @override
  Future<void> envoyer(Changement c) async {
    final table = _table(c.type);
    final id = idEnregistrement(c);
    final corps = jsonEncode({
      'parcelle': c.parcelleId,
      if (c.type == TypeChangement.statut) 'campagne': c.campagne,
      if (c.type == TypeChangement.statut) 'statut': c.valeur else 'memos': c.valeur,
      't': c.t,
      'appareil': appareil,
    });
    final existant = await _appel(() => _client.get(_uri('/api/collections/$table/records/$id'), headers: _entetes));
    if (existant.statusCode == 200) {
      final serveur = jsonDecode(existant.body) as Map<String, Object?>;
      final tServeur = (serveur['t'] as num?)?.toInt() ?? 0;
      final campagneServeur = (serveur['campagne'] as num?)?.toInt() ?? 0;
      // Le serveur a déjà plus récent (ou une campagne plus récente) : rien à faire.
      if (tServeur >= c.t || (c.campagne != null && campagneServeur > c.campagne!)) return;
      final r = await _appel(
        () => _client.patch(_uri('/api/collections/$table/records/$id'), headers: _entetes, body: corps),
      );
      // 404 : un autre téléphone vient d'envoyer plus récent ; on revérifiera.
      if (r.statusCode != 200) _echec('Envoi', r);
    } else if (existant.statusCode == 404) {
      final avecId = jsonEncode({...jsonDecode(corps) as Map<String, Object?>, 'id': id});
      final r = await _appel(
        () => _client.post(_uri('/api/collections/$table/records'), headers: _entetes, body: avecId),
      );
      if (r.statusCode != 200) _echec('Envoi', r);
    } else {
      _echec('Envoi', existant);
    }
  }

  @override
  Future<({List<Changement> changements, String? curseur})> recevoir(
    TypeChangement type, {
    int? campagne,
    String? depuis,
  }) async {
    final changements = <Changement>[];
    var curseur = depuis;
    for (var page = 1; ; page++) {
      final filtre = [
        if (type == TypeChangement.statut) 'campagne=$campagne',
        if (depuis != null) 'updated>="$depuis"',
      ].join(' && ');
      final r = await _appel(
        () => _client.get(
          _uri('/api/collections/${_table(type)}/records', {
            if (filtre.isNotEmpty) 'filter': filtre,
            'sort': 'updated',
            'perPage': '$_parPage',
            'page': '$page',
            'skipTotal': '1',
          }),
          headers: _entetes,
        ),
      );
      if (r.statusCode != 200) _echec('Réception', r);
      final items = ((jsonDecode(r.body) as Map<String, Object?>)['items'] as List?) ?? const [];
      for (final item in items.cast<Map<String, Object?>>()) {
        final parcelle = item['parcelle'];
        final t = (item['t'] as num?)?.toInt();
        final valeur = type == TypeChangement.statut ? item['statut'] : (item['memos'] ?? '');
        final camp = (item['campagne'] as num?)?.toInt();
        if (item['updated'] case final String maj) curseur = maj;
        if (parcelle is! String || t == null || valeur is! String) continue;
        if (type == TypeChangement.statut && camp == null) continue;
        changements.add(Changement.recu(type: type, parcelleId: parcelle, campagne: camp, valeur: valeur, t: t));
      }
      if (items.length < _parPage) break;
    }
    return (changements: changements, curseur: curseur);
  }

  /// Identifiant de l'enregistrement sur le serveur (15 caractères a-z0-9,
  /// format imposé par PocketBase), toujours le même pour une maison :
  /// « s » ou « m » + l'identifiant cadastral (« 422340000A0123 ») en minuscules.
  static String idEnregistrement(Changement c) {
    final prefixe = c.type == TypeChangement.statut ? 's' : 'm';
    final id = c.parcelleId;
    if (RegExp(r'^[0-9A-Za-z]{14}$').hasMatch(id)) return '$prefixe${id.toLowerCase()}';
    // Bâtiment sans parcelle (« bat-u054gtzex ») : « x », la longueur, puis
    // l'identifiant complété par des zéros.
    final nettoye = id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (nettoye.length > 12) throw ArgumentError('Identifiant trop long pour le serveur : $id');
    return '${prefixe}x${nettoye.length.toRadixString(36)}${nettoye.padRight(12, '0')}';
  }
}
