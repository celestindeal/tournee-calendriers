import 'package:flutter/material.dart';

import '../models/parcelle.dart';
import '../models/statut.dart';
import '../state/tournee_controller.dart';
import 'itineraire.dart';
import 'memos.dart';

/// Panneau du bas : adresse de la parcelle touchée et gros boutons de statut (F2).
/// Choisir un statut l'enregistre et ferme le panneau.
/// Compact (4 boutons sur une rangée) pour laisser voir la carte.
class PanneauStatut extends StatelessWidget {
  const PanneauStatut({super.key, required this.controller, required this.parcelle});

  final TourneeController controller;
  final Parcelle parcelle;

  static const _statutsPrincipaux = [Statut.achete, Statut.aRepasser, Statut.refus, Statut.nonConcerne];

  /// Libellés courts : quatre boutons tiennent sur la largeur d'un téléphone.
  static String libelleCourt(Statut statut) => switch (statut) {
        Statut.achete => 'Acheté',
        Statut.aRepasser => 'À repasser',
        Statut.refus => 'Refus',
        Statut.nonConcerne => 'Non concerné',
        Statut.nonVisite => 'Non visité',
      };

  void _choisir(Statut statut) {
    controller.selectionner(null);
    controller.changerStatut(parcelle.id, statut);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discret = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final actuel = controller.statutDe(parcelle.id);
    final memos = controller.memosDe(parcelle.id);
    final precedent = controller.statutPrecedent(parcelle.id);

    return Material(
      elevation: 12,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      parcelle.adresse ?? 'Adresse inconnue',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Itinéraire jusqu'au bâtiment principal (Plans, Google Maps ou Waze).
                  BoutonItineraire(destination: parcelle.centre, titre: parcelle.adresse),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close),
                    onPressed: () => controller.selectionner(null),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  [
                    actuel.libelle,
                    ?controller.jeu.nomCommune(parcelle.codeInsee), // l'adresse ne dit pas la commune
                    'terrain de ${parcelle.surfaceM2.round()} m²',
                    if (parcelle.batiments.length > 1) '${parcelle.batiments.length} bâtiments',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: discret,
                ),
              ),
              // Une seule ligne : statut de l'an dernier, mémos, bouton « Mémos ».
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (precedent != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history, size: 16, color: precedent.statut.couleur),
                              const SizedBox(width: 3),
                              Text(
                                'En ${precedent.annee} : ${precedent.statut.libelle}',
                                key: const Key('statut-precedent'),
                                style: discret,
                              ),
                            ],
                          ),
                        if (memos.isNotEmpty)
                          PucesMemos(memos: memos)
                        else if (precedent == null)
                          Text('Aucun mémo', style: discret),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('bouton-memos'),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Mémos'),
                    onPressed: () => ouvrirFeuilleMemos(context, controller, parcelle.id, titre: parcelle.adresse),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    for (final (i, s) in _statutsPrincipaux.indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(child: _BoutonStatut(statut: s, actif: s == actuel, onPressed: () => _choisir(s))),
                    ],
                  ],
                ),
              ),
              if (actuel != Statut.nonVisite)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: TextButton.icon(
                    key: const Key('bouton-nonVisite'),
                    icon: const Icon(Icons.undo, size: 18),
                    onPressed: () => _choisir(Statut.nonVisite),
                    label: const Text('Remettre en « non visité »'),
                  ),
                )
              else
                const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonStatut extends StatelessWidget {
  const _BoutonStatut({required this.statut, required this.actif, required this.onPressed});

  final Statut statut;
  final bool actif;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: Key('bouton-${statut.name}'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: statut.couleur,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 60),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: actif ? const BorderSide(color: Colors.black, width: 3) : BorderSide.none,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (actif) const Icon(Icons.check_circle, size: 16),
          Text(PanneauStatut.libelleCourt(statut), textAlign: TextAlign.center, maxLines: 2),
        ],
      ),
    );
  }
}
