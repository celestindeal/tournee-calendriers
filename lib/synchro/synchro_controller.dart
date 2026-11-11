import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/tournee_repository.dart';
import '../journal.dart';
import '../state/tournee_controller.dart';
import 'changement.dart';
import 'serveur_synchro.dart';

/// Où en est la synchronisation (affiché dans le menu et sur la carte).
enum EtatSynchro {
  desactivee('Désactivée'),
  enCours('Synchronisation…'),
  aJour('À jour'),
  horsLigne('Hors ligne'),
  erreur('Erreur');

  const EtatSynchro(this.libelle);
  final String libelle;
}

/// Réglages saisis par l'utilisateur.
class ConfigSynchro {
  const ConfigSynchro({required this.adresse, required this.code, required this.appareil});

  final String adresse;
  final String code;

  /// Identifiant aléatoire de ce téléphone (rien de personnel).
  final String appareil;

  Map<String, Object?> versJson() => {'adresse': adresse, 'code': code, 'appareil': appareil};

  static ConfigSynchro? depuisJson(Map<String, Object?>? json) {
    final a = json?['adresse'], c = json?['code'], ap = json?['appareil'];
    if (a is! String || c is! String || ap is! String) return null;
    return ConfigSynchro(adresse: a, code: c, appareil: ap);
  }
}

/// Synchronisation entre téléphones, par le serveur de la Raspberry Pi.
///
/// Le téléphone reste la référence : tout marche sans réseau. Chaque
/// modification est mise dans une file d'attente (gardée dans la base),
/// envoyée dès que possible ; les modifications des autres téléphones sont
/// récupérées toutes les [intervalle]. Pour une même maison, la modification
/// la plus récente gagne.
class SynchroController extends ChangeNotifier {
  SynchroController({
    required this._repo,
    required this._tournee,
    required this._fabriqueServeur,
    this.intervalle = const Duration(seconds: 30),
    this.attenteApresModif = const Duration(seconds: 2),
    DateTime Function()? horloge,
  }) : _horloge = horloge ?? DateTime.now;

  final TourneeRepository _repo;
  final TourneeController _tournee;
  final ServeurSynchro Function(ConfigSynchro config) _fabriqueServeur;
  final Duration intervalle;
  final Duration attenteApresModif;
  final DateTime Function() _horloge;

  static const _cleConfig = 'config';
  static const _cleDernierSucces = 'dernierSucces';

  ConfigSynchro? _config;
  ServeurSynchro? _serveur;
  EtatSynchro _etat = EtatSynchro.desactivee;
  String? _message;
  DateTime? _dernierSucces;
  final Map<String, Changement> _attente = {};
  final Map<String, int> _versions = {};
  Timer? _minuterie;
  Timer? _envoiProche;
  Future<void>? _enCours;
  bool _relancer = false;

  ConfigSynchro? get config => _config;
  bool get active => _config != null;
  EtatSynchro get etat => _etat;

  /// Explication de la dernière erreur, ou `null`.
  String? get message => _message;
  DateTime? get dernierSucces => _dernierSucces;
  int get nbEnAttente => _attente.length;

  /// Lit les réglages et la file d'attente ; démarre si la synchro est configurée.
  Future<void> charger() async {
    _tournee.surChangementsLocaux = _surChangementsLocaux;
    _tournee.synchro = this;
    _config = ConfigSynchro.depuisJson(await _repo.lireReglageSynchro(_cleConfig));
    if (await _repo.lireReglageSynchro(_cleDernierSucces) case {'t': final int t}) {
      _dernierSucces = DateTime.fromMillisecondsSinceEpoch(t, isUtc: true);
    }
    _attente.clear();
    for (final json in (await _repo.lireAttente()).values) {
      final c = Changement.depuisJson(json);
      if (c != null) _attente[c.cle] = c;
    }
    _versions
      ..clear()
      ..addAll(await _repo.lireVersions());
    if (_config != null) _demarrer();
    notifyListeners();
  }

  /// Vérifie l'adresse et le code, puis active la synchronisation. Au premier
  /// branchement, toute la tournée de ce téléphone est proposée au serveur
  /// (qui garde, maison par maison, la version la plus récente).
  /// Lève [ErreurSynchro] si le serveur refuse.
  Future<void> configurer({required String adresse, required String code}) async {
    final config = ConfigSynchro(
      adresse: ServeurPocketBase.normaliserAdresse(adresse),
      code: code.trim(),
      appareil: _config?.appareil ?? _nouvelIdAppareil(),
    );
    final serveur = _fabriqueServeur(config);
    await serveur.verifierAcces();
    await _arreter();
    await _repo.effacerSynchro();
    _attente.clear();
    _versions.clear();
    _dernierSucces = null;
    await _repo.ecrireReglageSynchro(_cleConfig, config.versJson());
    _config = config;
    _serveur = serveur;
    await _mettreEnAttente(_tournee.toutPourSynchro());
    _demarrer(passageImmediat: false);
    notifyListeners();
    await synchroniser();
  }

  /// Arrête la synchronisation et oublie l'adresse et le code. Les données
  /// du téléphone ne changent pas.
  Future<void> desactiver() async {
    await _arreter();
    await _repo.effacerSynchro();
    _config = null;
    _serveur = null;
    _attente.clear();
    _versions.clear();
    _dernierSucces = null;
    _message = null;
    _etat = EtatSynchro.desactivee;
    notifyListeners();
  }

  void _demarrer({bool passageImmediat = true}) {
    _serveur ??= _fabriqueServeur(_config!);
    _minuterie?.cancel();
    _minuterie = Timer.periodic(intervalle, (_) => synchroniser());
    // Premier passage tout de suite (sans attendre la minuterie).
    if (passageImmediat) scheduleMicrotask(synchroniser);
  }

  Future<void> _arreter() async {
    _minuterie?.cancel();
    _envoiProche?.cancel();
    _minuterie = null;
    _envoiProche = null;
    await _enCours;
  }

  void _surChangementsLocaux(List<Changement> changements) {
    if (!active) return;
    _mettreEnAttente(changements).then((_) {
      notifyListeners();
      _envoiProche?.cancel();
      _envoiProche = Timer(attenteApresModif, synchroniser);
    }, onError: (Object e, StackTrace pile) => Journal.instance.ajouter('Synchro (mise en attente) : $e', pile));
  }

  Future<void> _mettreEnAttente(List<Changement> changements) async {
    final versions = <String, int>{};
    for (final c in changements) {
      final deja = _attente[c.cle];
      if (deja != null && deja.t >= c.t) continue;
      _attente[c.cle] = c;
      await _repo.mettreEnAttente(c.cle, c.versJson());
      if ((_versions[c.cle] ?? 0) < c.t) versions[c.cle] = c.t;
    }
    _versions.addAll(versions);
    await _repo.ecrireVersions(versions);
  }

  /// Envoie ce qui est en attente puis récupère les changements des autres.
  /// Un seul passage à la fois ; un appel pendant un passage en relance un
  /// (le futur renvoyé se termine après ce nouveau passage).
  Future<void> synchroniser() {
    if (!active) return Future.value();
    if (_enCours != null) {
      _relancer = true;
      return _enCours!;
    }
    return _enCours = _boucle();
  }

  Future<void> _boucle() async {
    try {
      do {
        _relancer = false;
        await _passage();
      } while (_relancer && active);
    } finally {
      _enCours = null;
    }
  }

  Future<void> _passage() async {
    final serveur = _serveur;
    final campagne = _tournee.campagne?.annee;
    if (serveur == null || campagne == null) return;
    _etat = EtatSynchro.enCours;
    notifyListeners();
    try {
      await serveur.verifierAcces();

      // 1. Envoi, du plus ancien au plus récent.
      final aEnvoyer = _attente.values.toList()..sort((a, b) => a.t.compareTo(b.t));
      for (final c in aEnvoyer) {
        await serveur.envoyer(c);
        await _repo.retirerAttente(c.cle, c.t);
        if (identical(_attente[c.cle], c)) _attente.remove(c.cle);
        notifyListeners();
      }

      // 2. Réception des changements des autres téléphones.
      for (final (type, cle) in [
        (TypeChangement.statut, 'curseur-statuts-$campagne'),
        (TypeChangement.memos, 'curseur-memos'),
      ]) {
        final depuis = (await _repo.lireReglageSynchro(cle))?['u'] as String?;
        final recu = await serveur.recevoir(type, campagne: campagne, depuis: depuis);
        final nouveaux = <Changement>[];
        final versions = <String, int>{};
        for (final c in recu.changements) {
          final connu = max(_versions[c.cle] ?? 0, _tournee.dateLocale(c) ?? 0);
          // Une modification locale encore en attente plus récente l'emporte.
          final enAttente = _attente[c.cle]?.t ?? 0;
          if (c.t > connu && c.t > enAttente) {
            nouveaux.add(c);
            versions[c.cle] = c.t;
          }
        }
        if (nouveaux.isNotEmpty) {
          await _tournee.appliquerDistants(nouveaux);
          _versions.addAll(versions);
          await _repo.ecrireVersions(versions);
        }
        if (recu.curseur != null) await _repo.ecrireReglageSynchro(cle, {'u': recu.curseur});
      }

      _dernierSucces = _horloge().toUtc();
      await _repo.ecrireReglageSynchro(_cleDernierSucces, {'t': _dernierSucces!.millisecondsSinceEpoch});
      _etat = EtatSynchro.aJour;
      _message = null;
    } on ErreurSynchro catch (e) {
      _etat = e.horsLigne ? EtatSynchro.horsLigne : EtatSynchro.erreur;
      _message = e.message;
      if (!e.horsLigne) Journal.instance.ajouter('Synchro : ${e.message}');
    } catch (e, pile) {
      _etat = EtatSynchro.erreur;
      _message = 'Erreur inattendue (voir Diagnostic).';
      Journal.instance.ajouter('Synchro : $e', pile);
    }
    notifyListeners();
  }

  static String _nouvelIdAppareil() {
    const lettres = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(8, (_) => lettres[r.nextInt(lettres.length)]).join();
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    _envoiProche?.cancel();
    super.dispose();
  }
}
