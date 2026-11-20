import 'package:flutter/material.dart';

import '../models/avancement.dart';
import '../models/filtre.dart';
import '../models/statut.dart';
import '../state/tournee_controller.dart';
import 'couche_parcelles.dart' show couleurTournee;
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
                  // Toucher le compteur : le détail de l'avancement.
                  child: InkWell(
                    key: const Key('bouton-detail-avancement'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => afficherDetailAvancement(context, controller),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // « 128 faites · 195 visitées / 220 » : sans puis avec les maisons
                        // à repasser. Rétréci plutôt que coupé si la place manque.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            key: const Key('compteur'),
                            TextSpan(
                              style: theme.textTheme.titleSmall,
                              children: [
                                TextSpan(
                                  text: '${a.faits}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: ' ${a.faits <= 1 ? 'faite' : 'faites'}'),
                                TextSpan(
                                  text: '  ·  ',
                                  style: TextStyle(color: theme.colorScheme.outline),
                                ),
                                TextSpan(
                                  text: '${a.visitees}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: ' ${a.visitees <= 1 ? 'visitée' : 'visitées'} / ${a.total}'),
                              ],
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Le compteur porte sur ma tournée quand j'en ai choisi une.
                            if (controller.maTournee case final t?) ...[
                              Text(
                                'Tournée ${t.numero}',
                                key: const Key('compteur-tournee'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: couleurTournee,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(child: BarreBicolore(avancement: a)),
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
                                builder: (context, _) =>
                                    IconeSynchro(key: const Key('icone-synchro'), synchro: synchro),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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

/// Gris de la partie « pas encore visitées » : visible sur le fond rosé des cartes.
const _grisReste = Color(0xFFD6D6D6);

/// Barre de progression en deux couleurs : vert = faites, orange = à repasser
/// (juste après), gris = pas encore visitées.
class BarreBicolore extends StatelessWidget {
  const BarreBicolore({super.key, required this.avancement, this.hauteur = 5});

  final Avancement avancement;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    final a = avancement;
    final reste = (a.total - a.visitees).clamp(0, a.total);
    return ClipRRect(
      key: const Key('barre-bicolore'),
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: hauteur,
        child: a.total <= 0
            ? ColoredBox(color: _grisReste)
            : Row(
                children: [
                  if (a.faits > 0)
                    Expanded(
                      flex: a.faits,
                      child: ColoredBox(color: Statut.achete.couleur),
                    ),
                  if (a.aRepasser > 0)
                    Expanded(
                      flex: a.aRepasser,
                      child: ColoredBox(color: Statut.aRepasser.couleur),
                    ),
                  if (reste > 0)
                    Expanded(
                      flex: reste,
                      child: ColoredBox(color: _grisReste),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Détail de l'avancement (en touchant le compteur).
Future<void> afficherDetailAvancement(BuildContext context, TourneeController controller) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final a = controller.avancement;
      final theme = Theme.of(context);
      final tournee = controller.maTournee;
      String pc(int n) => a.total <= 0 ? '' : ' (${n * 100 ~/ a.total} %)';
      Widget ligne(Color? couleur, String libelle, String valeur, {bool gras = false, Key? key}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: couleur ?? Colors.transparent, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(libelle, style: gras ? const TextStyle(fontWeight: FontWeight.bold) : null),
            ),
            Text(
              valeur,
              key: key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tournee == null ? 'Avancement de toute la carte' : 'Avancement de la ${tournee.nom.toLowerCase()}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              BarreBicolore(avancement: a, hauteur: 10),
              const SizedBox(height: 10),
              ligne(
                Statut.achete.couleur,
                'Faites (achetées + refus)',
                '${a.faits}${pc(a.faits)}',
                key: const Key('detail-faites'),
              ),
              ligne(Statut.aRepasser.couleur, 'À repasser', '${a.aRepasser}'),
              ligne(
                _grisReste,
                'Pas encore visitées',
                '${a.nonVisites}',
                key: const Key('detail-non-visitees'),
              ),
              const Divider(),
              ligne(
                null,
                'Premier tour (visitées au moins une fois)',
                '${a.visitees}${pc(a.visitees)}',
                gras: true,
                key: const Key('detail-visitees'),
              ),
              ligne(null, 'Maisons comptées', '${a.total}'),
              ligne(Statut.nonConcerne.couleur, 'Non concernées (pas comptées)', '${a.nonConcernes}'),
            ],
          ),
        ),
      );
    },
  );
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
