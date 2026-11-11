import 'package:flutter/material.dart';

import '../models/filtre.dart';
import '../models/statut.dart';
import '../state/tournee_controller.dart';
import 'synchro_page.dart';

/// Barre fine en haut de la carte : compteur « 132 / 480 faits (27 %) »,
/// barre de progression, nombre à repasser (F5), loupe et menu.
/// La légende et le filtre sont dans le menu, pour laisser la place à la carte.
class BarreAvancement extends StatelessWidget {
  const BarreAvancement({super.key, required this.controller, this.onMenu, this.onRecherche, this.estTest = false});

  final TourneeController controller;

  /// Ouvre le menu (bouton affiché seulement si fourni).
  final VoidCallback? onMenu;

  /// Ouvre la recherche d'adresse (bouton affiché seulement si fourni).
  final VoidCallback? onRecherche;

  /// Environnement de test : badge « TEST » et bordure orange.
  final bool estTest;

  static const couleurTest = Color(0xFFEF6C00);

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: estTest ? const BorderSide(color: couleurTest, width: 2) : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            child: Row(
              children: [
                if (estTest) ...[
                  Container(
                    key: const Key('badge-test'),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: couleurTest, borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                      'TEST',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${a.faits} / ${a.total} faits (${a.pourcentage} %)',
                        key: const Key('compteur'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: a.total == 0 ? 0 : a.faits / a.total,
                                minHeight: 5,
                                color: Statut.achete.couleur,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${a.aRepasser} à repasser',
                            key: const Key('compteur-a-repasser'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Statut.aRepasser.couleur,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // État de la synchronisation entre téléphones, si elle est réglée.
                          if (controller.synchro case final synchro? when synchro.active) ...[
                            const SizedBox(width: 6),
                            ListenableBuilder(
                              listenable: synchro,
                              builder: (context, _) => IconeSynchro(key: const Key('icone-synchro'), synchro: synchro),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (onRecherche != null)
                  IconButton(
                    key: const Key('bouton-recherche'),
                    tooltip: 'Rechercher une adresse',
                    icon: const Icon(Icons.search),
                    onPressed: onRecherche,
                  ),
                if (onMenu != null)
                  IconButton(
                    key: const Key('bouton-menu'),
                    tooltip: 'Menu',
                    icon: const Icon(Icons.menu),
                    onPressed: onMenu,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Petite étiquette sous la barre quand un filtre cache des maisons :
/// on voit qu'il est actif et on l'enlève d'un toucher.
class IndicateurFiltre extends StatelessWidget {
  const IndicateurFiltre({super.key, required this.controller});

  final TourneeController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final filtre = controller.filtre;
        if (filtre == Filtre.toutes) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              key: const Key('filtre-actif'),
              elevation: 3,
              backgroundColor: Theme.of(context).colorScheme.surface,
              avatar: const Icon(Icons.filter_alt, size: 18),
              label: Text('Seulement : ${filtre.libelle.toLowerCase()}'),
              deleteButtonTooltipMessage: 'Afficher toutes les maisons',
              onDeleted: () => controller.changerFiltre(Filtre.toutes),
              onPressed: () => controller.changerFiltre(Filtre.toutes),
            ),
          ),
        );
      },
    );
  }
}

/// Légende des couleurs (dans le menu).
class LegendeCouleurs extends StatelessWidget {
  const LegendeCouleurs({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final s in Statut.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: s.couleur, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 6),
              Text(s.libelle),
            ],
          ),
      ],
    );
  }
}
