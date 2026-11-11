import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../journal.dart';
import '../platform/plateforme.dart';
import '../state/tournee_controller.dart';
import 'formats.dart';

/// État de l'app et dernières erreurs (ARCHITECTURE §7.10).
/// Sans Mac, c'est le seul moyen de savoir ce qui se passe sur l'iPhone.
class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key, required this.controller, required this.plateforme});

  final TourneeController controller;
  final Plateforme plateforme;

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  late final Future<List<(String, String)>> _infos = _collecter();

  Future<List<(String, String)>> _collecter() async {
    final c = widget.controller;
    final p = widget.plateforme;
    final maintenant = DateTime.now();
    final inconnus = c.nbEtatsInconnus;
    return [
      ('Version de l\'app', versionApp),
      ('Carte', '${c.jeu.nomCommune}, ${c.jeu.batiments.length} bâtiments (version ${c.jeu.version})'),
      ('Statuts enregistrés', '${c.nbEtatsEnregistres}${inconnus > 0 ? ' (dont $inconnus hors carte)' : ''}'),
      ('Avancement', c.avancement.resume),
      ('Campagne commencée', c.campagne == null ? 'inconnue' : dateCourte(c.campagne!.debut)),
      ('Dernier export', c.dernierExport == null ? 'jamais' : decrireMoment(c.dernierExport!, maintenant)),
      ('Ouverte depuis l\'écran d\'accueil', p.estAppInstallee ? 'oui' : 'non (onglet du navigateur)'),
      ('Stockage persistant', await p.stockagePersistant() ? 'accordé' : 'non accordé'),
      ('Hors-ligne (service worker)', await p.serviceWorker()),
      ('Navigateur', p.navigateur),
    ];
  }

  String _texte(List<(String, String)> infos, List<String> erreurs) => [
        'Diagnostic – appli tournée calendriers',
        for (final (nom, valeur) in infos) '$nom : $valeur',
        '',
        'Erreurs récentes :',
        if (erreurs.isEmpty) 'aucune' else ...erreurs,
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final erreurs = Journal.instance.lignes;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic')),
      body: FutureBuilder<List<(String, String)>>(
        future: _infos,
        builder: (context, etat) {
          final infos = etat.data;
          if (infos == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (nom, valeur) in infos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                      SelectableText(valeur),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Text('Erreurs récentes', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (erreurs.isEmpty)
                const Text('Aucune erreur depuis l\'ouverture de l\'app.')
              else
                for (final e in erreurs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectableText(e, style: theme.textTheme.bodySmall),
                  ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('diagnostic-copier'),
                icon: const Icon(Icons.copy),
                label: const Text('Copier le diagnostic'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _texte(infos, erreurs)));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Diagnostic copié : collez-le dans un message.')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
