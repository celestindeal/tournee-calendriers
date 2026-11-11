import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../state/tournee_controller.dart';
import 'barre_avancement.dart';
import 'conseil_installation.dart';
import 'couche_batiments.dart';
import 'panneau_statut.dart';

/// Écran principal : carte, compteur en haut, panneau de statut en bas.
class CartePage extends StatefulWidget {
  const CartePage({super.key, required this.controller, this.conseilInstallation = false});

  final TourneeController controller;

  /// Vrai si l'app est ouverte dans un onglet du navigateur au lieu de
  /// l'icône de l'écran d'accueil (ARCHITECTURE §7.5).
  final bool conseilInstallation;

  @override
  State<CartePage> createState() => _CartePageState();
}

class _CartePageState extends State<CartePage> {
  TourneeController get _controller => widget.controller;
  late bool _conseilVisible = widget.conseilInstallation;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_afficherErreur);
  }

  @override
  void dispose() {
    _controller.removeListener(_afficherErreur);
    super.dispose();
  }

  void _afficherErreur() {
    final message = _controller.derniereErreur;
    if (message == null) return;
    _controller.effacerErreur();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jeu = _controller.jeu;
    final emprise = LatLngBounds(jeu.sudOuest, jeu.nordEst);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(bounds: emprise, padding: const EdgeInsets.all(24)),
              cameraConstraint: CameraConstraint.containCenter(bounds: emprise),
              minZoom: 12,
              maxZoom: 19,
              // Fond neutre quand les tuiles ne se chargent pas (hors-ligne).
              backgroundColor: const Color(0xFFEDEDED),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              // Toucher à côté des bâtiments : ferme le panneau.
              onTap: (_, _) => _controller.selectionner(null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.amicale.tournee_calendriers',
                maxNativeZoom: 19,
                keepBuffer: 1,
                panBuffer: 0,
              ),
              CoucheBatiments(controller: _controller),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  const TextSourceAttribution('Contributeurs OpenStreetMap'),
                  for (final source in jeu.sources) TextSourceAttribution(source),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              minimum: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BarreAvancement(controller: _controller),
                  if (_conseilVisible) ...[
                    const SizedBox(height: 8),
                    ConseilInstallation(onFermer: () => setState(() => _conseilVisible = false)),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final selection = _controller.selection;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  // Le panneau glisse depuis le bas de l'écran.
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                  child: selection == null
                      ? const SizedBox.shrink()
                      : PanneauStatut(
                          key: ValueKey(selection.id),
                          controller: _controller,
                          batiment: selection,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
