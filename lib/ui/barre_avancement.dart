import 'package:flutter/material.dart';

import '../models/statut.dart';
import '../state/tournee_controller.dart';

/// Compteur « 132 / 480 faits (27 %) – 45 à repasser » et légende (F5).
class BarreAvancement extends StatelessWidget {
  const BarreAvancement({super.key, required this.controller, this.onMenu});

  final TourneeController controller;

  /// Ouvre le menu (bouton affiché seulement si fourni).
  final VoidCallback? onMenu;

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
