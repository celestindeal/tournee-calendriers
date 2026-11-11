import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/parcelle.dart';
import '../models/statut.dart';
import '../state/tournee_controller.dart';

/// Les parcelles colorées selon leur statut (F1, F3) : le terrain en
/// dessous, les bâtiments au-dessus. On touche un bâtiment pour ouvrir le
/// panneau de sa parcelle (F2).
class CoucheParcelles extends StatefulWidget {
  const CoucheParcelles({super.key, required this.controller});

  final TourneeController controller;

  @override
  State<CoucheParcelles> createState() => _CoucheParcellesState();
}

/// Polygones déjà construits pour une parcelle, avec le statut qu'ils affichent.
typedef _Dessin = ({Statut statut, List<Polygon<String>> terrain, List<Polygon<String>> batiments});

class _CoucheParcellesState extends State<CoucheParcelles> {
  final LayerHitNotifier<String> _toucher = ValueNotifier(null);

  /// Seules les parcelles dont le statut a changé sont reconstruites.
  final Map<String, _Dessin> _cache = {};

  @override
  void dispose() {
    _toucher.dispose();
    super.dispose();
  }

  _Dessin _dessinDe(Parcelle p) {
    final statut = widget.controller.statutDe(p.id);
    final enCache = _cache[p.id];
    if (enCache != null && enCache.statut == statut) return enCache;
    final nonVisite = statut == Statut.nonVisite;
    final dessin = (
      statut: statut,
      // Terrain : simple contour gris fin tant que rien n'est fait (carte lisible),
      // rempli de la couleur du statut ensuite.
      terrain: [
        for (final contour in p.contours)
          Polygon<String>(
            points: contour,
            color: nonVisite ? null : statut.couleur.withValues(alpha: 0.35),
            borderColor: nonVisite ? const Color(0x99757575) : statut.couleur,
            borderStrokeWidth: nonVisite ? 1 : 2,
            strokeCap: StrokeCap.butt,
            strokeJoin: StrokeJoin.miter,
          ),
      ],
      // Bâtiments : ce qu'on touche. « Non visité » : contour foncé pour
      // ressortir sur les bâtiments gris du fond OpenStreetMap.
      batiments: [
        for (final contour in p.batiments)
          Polygon<String>(
            points: contour,
            hitValue: p.id,
            color: statut.couleur.withValues(alpha: nonVisite ? 0.55 : 0.9),
            borderColor: nonVisite ? const Color(0xFF424242) : statut.couleur,
            borderStrokeWidth: 1.5,
            strokeCap: StrokeCap.butt,
            strokeJoin: StrokeJoin.miter,
          ),
      ],
    );
    _cache[p.id] = dessin;
    return dessin;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final dessins = [for (final p in controller.jeu.parcelles) _dessinDe(p)];
        final selection = controller.selection;
        return Stack(
          children: [
            // Les terrains ne captent pas le toucher (consigne : on touche la maison).
            IgnorePointer(
              child: PolygonLayer<String>(
                simplificationTolerance: 0, // déjà simplifiés par tool/preparer_donnees.dart
                polygonLabels: false,
                polygons: [for (final d in dessins) ...d.terrain],
              ),
            ),
            GestureDetector(
              onTap: () {
                final ids = _toucher.value?.hitValues ?? const [];
                if (ids.isNotEmpty) controller.selectionner(ids.first);
              },
              child: PolygonLayer<String>(
                hitNotifier: _toucher,
                simplificationTolerance: 0,
                polygonLabels: false,
                polygons: [for (final d in dessins) ...d.batiments],
              ),
            ),
            if (selection != null)
              // Contour épais autour de la parcelle sélectionnée (ne capte pas le toucher).
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
