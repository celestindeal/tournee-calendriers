import 'package:flutter/material.dart';

import '../synchro/serveur_synchro.dart';
import '../synchro/synchro_controller.dart';
import 'formats.dart';

/// Réglage et état de la synchronisation entre téléphones.
class SynchroPage extends StatefulWidget {
  const SynchroPage({super.key, required this.synchro});

  final SynchroController synchro;

  @override
  State<SynchroPage> createState() => _SynchroPageState();
}

class _SynchroPageState extends State<SynchroPage> {
  SynchroController get _s => widget.synchro;

  late final _adresse = TextEditingController(text: _s.config?.adresse ?? '');
  final _code = TextEditingController();
  bool _codeVisible = false;
  bool _connexion = false;
  String? _erreur;

  /// Formulaire affiché même si la synchro est active (« Changer de serveur »).
  bool _modifier = false;

  @override
  void dispose() {
    _adresse.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    if (_adresse.text.trim().isEmpty || _code.text.trim().isEmpty) {
      setState(() => _erreur = 'Saisissez l\'adresse du serveur et le code d\'équipe.');
      return;
    }
    setState(() {
      _connexion = true;
      _erreur = null;
    });
    try {
      await _s.configurer(adresse: _adresse.text, code: _code.text);
      if (!mounted) return;
      _code.clear();
      setState(() => _modifier = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synchronisation activée.')));
    } on ErreurSynchro catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (e) {
      if (mounted) setState(() => _erreur = 'Connexion impossible : $e');
    } finally {
      if (mounted) setState(() => _connexion = false);
    }
  }

  Future<void> _desactiver() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arrêter la synchronisation ?'),
        content: Text(
          _s.nbEnAttente > 0
              ? '${_s.nbEnAttente} changement(s) n\'ont pas encore été envoyés : les autres ne les verront pas. '
                    'Les maisons de ce téléphone ne changent pas.'
              : 'Les maisons de ce téléphone ne changent pas. Les changements des autres ne seront plus reçus.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Arrêter')),
        ],
      ),
    );
    if (ok == true) await _s.desactiver();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Synchronisation')),
      body: ListenableBuilder(
        listenable: _s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_s.active) ...[
              _Etat(synchro: _s),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('bouton-synchroniser'),
                onPressed: _s.etat == EtatSynchro.enCours ? null : _s.synchroniser,
                icon: const Icon(Icons.sync),
                label: const Text('Synchroniser maintenant'),
              ),
              const SizedBox(height: 8),
              if (!_modifier)
                OutlinedButton(
                  onPressed: () => setState(() => _modifier = true),
                  child: const Text('Changer de serveur ou de code'),
                ),
              TextButton(
                key: const Key('bouton-arreter-synchro'),
                onPressed: _desactiver,
                child: const Text('Arrêter la synchronisation'),
              ),
              const SizedBox(height: 16),
            ] else
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Pour travailler à plusieurs : chaque téléphone envoie ses maisons au serveur '
                  'de l\'équipe et reçoit celles des autres. L\'app continue de marcher sans réseau ; '
                  'tout part dès que le réseau revient. Si deux personnes changent la même maison, '
                  'la modification la plus récente gagne.\n\n'
                  'Demandez l\'adresse du serveur et le code d\'équipe au responsable.',
                ),
              ),
            if (!_s.active || _modifier) ...[
              TextField(
                key: const Key('champ-adresse-serveur'),
                controller: _adresse,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Adresse du serveur',
                  hintText: 'serveur-pompier.xxxx.ts.net',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('champ-code-equipe'),
                controller: _code,
                obscureText: !_codeVisible,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Code d\'équipe',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _codeVisible ? 'Cacher' : 'Afficher',
                    icon: Icon(_codeVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _codeVisible = !_codeVisible),
                  ),
                ),
                onSubmitted: (_) => _connecter(),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 8),
                Text(
                  _erreur!,
                  key: const Key('erreur-synchro'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('bouton-connecter'),
                onPressed: _connexion ? null : _connecter,
                child: _connexion
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Se connecter'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Etat extends StatelessWidget {
  const _Etat({required this.synchro});

  final SynchroController synchro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dernier = synchro.dernierSucces;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconeSynchro(synchro: synchro, taille: 28),
                const SizedBox(width: 12),
                Text(synchro.etat.libelle, key: const Key('etat-synchro'), style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('Serveur : ${synchro.config?.adresse ?? ''}'),
            Text(
              dernier == null
                  ? 'Jamais synchronisé'
                  : 'Dernière synchronisation : ${decrireMoment(dernier.toLocal(), DateTime.now())}',
            ),
            Text(
              synchro.nbEnAttente == 0
                  ? 'Tout a été envoyé.'
                  : '${synchro.nbEnAttente} changement(s) en attente d\'envoi.',
              key: const Key('attente-synchro'),
            ),
            if (synchro.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(synchro.message!, style: TextStyle(color: theme.colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Petite icône d'état (nuage) : à jour, en cours, hors ligne, erreur.
class IconeSynchro extends StatelessWidget {
  const IconeSynchro({super.key, required this.synchro, this.taille = 18});

  final SynchroController synchro;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final (icone, couleur) = switch (synchro.etat) {
      EtatSynchro.desactivee => (Icons.cloud_off, Colors.grey),
      EtatSynchro.enCours => (Icons.cloud_sync, Colors.blueGrey),
      EtatSynchro.aJour when synchro.nbEnAttente > 0 => (Icons.cloud_upload, Colors.orange.shade800),
      EtatSynchro.aJour => (Icons.cloud_done, Colors.green.shade700),
      EtatSynchro.horsLigne => (Icons.cloud_off, Colors.orange.shade800),
      EtatSynchro.erreur => (Icons.sync_problem, Colors.red.shade700),
    };
    return Icon(icone, size: taille, color: couleur, semanticLabel: 'Synchronisation : ${synchro.etat.libelle}');
  }
}
