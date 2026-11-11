import 'package:flutter/material.dart';

import '../journal.dart';
import '../state/tournee_controller.dart';
import 'export_tournee.dart';
import 'formats.dart';

/// Nouvelle campagne (F11) : 1. exporter la campagne en cours, 2. choisir
/// l'année et commencer. La campagne en cours est archivée, toutes les
/// maisons repassent en « non visité », les mémos sont gardés.
class NouvelleCampagnePage extends StatefulWidget {
  const NouvelleCampagnePage({super.key, required this.controller});

  final TourneeController controller;

  @override
  State<NouvelleCampagnePage> createState() => _NouvelleCampagnePageState();
}

class _NouvelleCampagnePageState extends State<NouvelleCampagnePage> {
  TourneeController get _c => widget.controller;

  late final int _anneeActuelle = _c.campagne?.annee ?? DateTime.now().year;

  /// Par défaut : l'année en cours si elle est après la campagne actuelle, sinon la suivante.
  late int _annee = DateTime.now().year > _anneeActuelle ? DateTime.now().year : _anneeActuelle + 1;

  bool _exporteIci = false;
  bool _enCours = false;

  Future<void> _exporter() async {
    final ok = await exporterTournee(context, _c);
    if (mounted) setState(() => _exporteIci = _exporteIci || ok);
  }

  Future<void> _commencer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commencer la campagne $_annee ?'),
        content: Text([
          if (!_exporteIci)
            'Attention : la campagne $_anneeActuelle n\'a pas été exportée depuis cette page. '
                'Sans export, son seul souvenir sera l\'archive dans ce téléphone.',
          'Toutes les maisons repasseront en « non visité ». '
              'La campagne $_anneeActuelle reste consultable (« En $_anneeActuelle : … »). '
              'Les mémos sont gardés.',
        ].join('\n\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          FilledButton(
            key: const Key('confirmer-nouvelle-campagne'),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Commencer $_annee'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _enCours = true);
    try {
      await _c.nouvelleCampagne(_annee);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Campagne $_annee commencée.')));
      Navigator.pop(context);
    } catch (e, pile) {
      Journal.instance.ajouter('Nouvelle campagne : $e', pile);
      if (!mounted) return;
      setState(() => _enCours = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('La nouvelle campagne n\'a pas pu commencer : rien n\'a été modifié.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dernier = _c.dernierExport;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle campagne')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Campagne $_anneeActuelle : ${_c.avancement.resume}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Commencer une nouvelle campagne archive celle-ci (statut final de chaque maison, '
            'consultable l\'an prochain), puis remet toutes les maisons à « non visité ». '
            'Les mémos (chien, plutôt le soir…) sont gardés. '
            'Seules les ${TourneeController.campagnesArchiveesGardees} dernières campagnes sont conservées.',
          ),
          const SizedBox(height: 24),
          Text('1. Sauvegarder la campagne $_anneeActuelle', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('exporter-avant-campagne'),
            icon: Icon(_exporteIci ? Icons.check_circle : Icons.ios_share),
            label: Text(_exporteIci ? 'Campagne $_anneeActuelle exportée' : 'Exporter la campagne $_anneeActuelle'),
            onPressed: _enCours ? null : _exporter,
          ),
          if (dernier != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Dernier export : ${decrireMoment(dernier, DateTime.now())}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 24),
          Text('2. Choisir l\'année et commencer', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Année précédente',
                icon: const Icon(Icons.remove),
                onPressed: _annee > _anneeActuelle + 1 && !_enCours ? () => setState(() => _annee--) : null,
              ),
              Expanded(
                child: Text(
                  'Campagne $_annee',
                  key: const Key('annee-nouvelle-campagne'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              IconButton.outlined(
                tooltip: 'Année suivante',
                icon: const Icon(Icons.add),
                onPressed: _enCours ? null : () => setState(() => _annee++),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('commencer-campagne'),
            icon: const Icon(Icons.restart_alt),
            label: Text('Commencer la campagne $_annee'),
            onPressed: _enCours ? null : _commencer,
          ),
        ],
      ),
    );
  }
}
