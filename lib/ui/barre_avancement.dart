import 'package:flutter/material.dart';

import '../models/filtre.dart';
import '../models/statut.dart';
import '../state/tournee_controller.dart';

/// Compteur « 132 / 480 faits (27 %) – 45 à repasser », légende (F5) et,
/// sur la carte, filtre d'affichage (F9).
class BarreAvancement extends StatelessWidget {
  const BarreAvancement({
    super.key,
    required this.controller,
    this.onMenu,
    this.onListes,
    this.onRecherche,
    this.afficherFiltre = false,
  });

  final TourneeController controller;

  /// Ouvre le menu (bouton affiché seulement si fourni).
  final VoidCallback? onMenu;

  /// Ouvre les listes de maisons (bouton affiché seulement si fourni).
  final VoidCallback? onListes;

  /// Ouvre la recherche d'adresse (bouton affiché seulement si fourni).
  final VoidCallback? onRecherche;

  /// Affiche le choix « Toutes / Non visitées / À repasser ».
  final bool afficherFiltre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final a = controller.avancement;
        return Card(
          elevation: 4,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.resume, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    if (onRecherche != null)
                      IconButton(
                        key: const Key('bouton-recherche'),
                        tooltip: 'Rechercher une adresse',
                        icon: const Icon(Icons.search),
                        visualDensity: VisualDensity.compact,
                        onPressed: onRecherche,
                      ),
                    if (onListes != null)
                      IconButton(
                        key: const Key('bouton-listes'),
                        tooltip: 'Listes des maisons',
                        icon: const Icon(Icons.format_list_bulleted),
                        visualDensity: VisualDensity.compact,
                        onPressed: onListes,
                      ),
                    if (onMenu != null)
                      IconButton(
                        key: const Key('bouton-menu'),
                        tooltip: 'Menu',
                        icon: const Icon(Icons.menu),
                        visualDensity: VisualDensity.compact,
                        onPressed: onMenu,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: a.total == 0 ? 0 : a.faits / a.total,
                    minHeight: 6,
                    color: Statut.achete.couleur,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [for (final s in Statut.values) _Legende(statut: s)],
                ),
                if (afficherFiltre) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<Filtre>(
                      key: const Key('filtre'),
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
                        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      segments: [
                        for (final f in Filtre.values)
                          ButtonSegment(value: f, label: Text(f.libelle, key: Key('filtre-${f.name}'))),
                      ],
                      selected: {controller.filtre},
                      onSelectionChanged: (choix) => controller.changerFiltre(choix.first),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Legende extends StatelessWidget {
  const _Legende({required this.statut});

  final Statut statut;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: statut.couleur, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(statut.libelle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
