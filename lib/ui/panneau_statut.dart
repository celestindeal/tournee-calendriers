import 'package:flutter/material.dart';

import '../models/parcelle.dart';
import '../models/statut.dart';
import '../state/tournee_controller.dart';
import 'itineraire.dart';

/// Panneau du bas : adresse de la parcelle touchée et gros boutons de statut (F2).
/// Choisir un statut l'enregistre et ferme le panneau.
class PanneauStatut extends StatelessWidget {
  const PanneauStatut({super.key, required this.controller, required this.parcelle});

  final TourneeController controller;
  final Parcelle parcelle;

  static const _statutsPrincipaux = [Statut.achete, Statut.aRepasser, Statut.refus, Statut.nonConcerne];

  void _choisir(Statut statut) {
    controller.selectionner(null);
    controller.changerStatut(parcelle.id, statut);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actuel = controller.statutDe(parcelle.id);

    return Material(
      elevation: 12,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      parcelle.adresse ?? 'Adresse inconnue',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              Text(
                [
                  actuel.libelle,
                  ?controller.jeu.nomCommune(parcelle.codeInsee), // l'adresse ne dit pas la commune
                  'terrain de ${parcelle.surfaceM2.round()} m²',
                  if (parcelle.batiments.length > 1) '${parcelle.batiments.length} bâtiments',
                ].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.6,
                  children: [
                    for (final s in _statutsPrincipaux)
                      _BoutonStatut(statut: s, actif: s == actuel, onPressed: () => _choisir(s)),
                  ],
                ),
              ),
              if (actuel != Statut.nonVisite)
                TextButton(
                  key: const Key('bouton-nonVisite'),
                  onPressed: () => _choisir(Statut.nonVisite),
                  child: const Text('Remettre en « non visité »'),
                ),
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
    return FilledButton.icon(
      key: Key('bouton-${statut.name}'),
      onPressed: onPressed,
      icon: actif ? const Icon(Icons.check_circle) : const SizedBox.shrink(),
      label: Text(statut.libelle, textAlign: TextAlign.center),
      style: FilledButton.styleFrom(
        backgroundColor: statut.couleur,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: actif ? const BorderSide(color: Colors.black, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}
