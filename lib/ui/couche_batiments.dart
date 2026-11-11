import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/batiment.dart';
import '../models/statut.dart';
import '../state/tournee_controller.dart';

/// Les bâtiments, colorés selon leur statut (F1, F3), et la détection du
/// toucher sur un bâtiment (F2).
class CoucheBatiments extends StatefulWidget {
  const CoucheBatiments({super.key, required this.controller});

  final TourneeController controller;

  @override
  State<CoucheBatiments> createState() => _CoucheBatimentsState();
}

class _CoucheBatimentsState extends State<CoucheBatiments> {
  final LayerHitNotifier<String> _toucher = ValueNotifier(null);

  /// Polygones déjà construits, par bâtiment, avec le statut qu'ils affichent.
  /// Seuls les bâtiments dont le statut a changé sont reconstruits.
  final Map<String, (Statut, List<Polygon<String>>)> _cache = {};

  @override
  void dispose() {
    _toucher.dispose();
    super.dispose();
  }

  List<Polygon<String>> _polygonesDe(Batiment b) {
    final statut = widget.controller.statutDe(b.id);
    final enCache = _cache[b.id];
    if (enCache != null && enCache.$1 == statut) return enCache.$2;
    // « Non visité » : contour foncé pour ressortir sur les bâtiments gris
    // déjà dessinés par le fond OpenStreetMap.
    final nonVisite = statut == Statut.nonVisite;
    final polygones = [
      for (final contour in b.contours)
        Polygon<String>(
          points: contour,
          hitValue: b.id,
          color: statut.couleur.withValues(alpha: nonVisite ? 0.55 : 0.8),
          borderColor: nonVisite ? const Color(0xFF424242) : statut.couleur,
          borderStrokeWidth: 1.5,
          strokeCap: StrokeCap.butt,
          strokeJoin: StrokeJoin.miter,
        ),
    ];
    _cache[b.id] = (statut, polygones);
    return polygones;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final selection = controller.selection;
        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                final ids = _toucher.value?.hitValues ?? const [];
                if (ids.isNotEmpty) controller.selectionner(ids.first);
              },
              child: PolygonLayer<String>(
                hitNotifier: _toucher,
                // Les contours sont déjà simplifiés par tool/preparer_donnees.dart.
                simplificationTolerance: 0,
                polygonLabels: false,
                polygons: [
                  for (final b in controller.jeu.batiments) ..._polygonesDe(b),
                ],
              ),
            ),
            if (selection != null)
              // Contour épais autour du bâtiment sélectionné (ne capte pas le toucher).
              IgnorePointer(
                child: PolygonLayer(
                  simplificationTolerance: 0,
                  polygonLabels: false,
                  polygons: [
                    for (final contour in selection.contours)
                      Polygon(points: contour, borderColor: Colors.black, borderStrokeWidth: 4),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
