import 'package:flutter/material.dart';

import '../synchro/synchro_controller.dart';
import 'formats.dart';

/// État de la synchronisation entre téléphones. Rien à régler : l'adresse du
/// serveur et la clé sont intégrées à l'app.
class SynchroPage extends StatelessWidget {
  const SynchroPage({super.key, required this.synchro});

  final SynchroController synchro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Synchronisation')),
      body: ListenableBuilder(
        listenable: synchro,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Tous les téléphones partagent la même tournée : chaque maison cochée est envoyée '
                'au serveur et apparaît chez les autres. L\'app continue de marcher sans réseau ; '
                'tout part dès que le réseau revient. Si deux personnes changent la même maison, '
                'la modification la plus récente gagne.',
              ),
            ),
            if (synchro.active) ...[
              _Etat(synchro: synchro),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('bouton-synchroniser'),
                onPressed: synchro.etat == EtatSynchro.enCours ? null : synchro.synchroniser,
                icon: const Icon(Icons.sync),
                label: const Text('Synchroniser maintenant'),
              ),
            ] else
              const Text(
                'La synchronisation n\'est pas activée dans cette version de l\'app.',
                key: Key('synchro-indisponible'),
              ),
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
