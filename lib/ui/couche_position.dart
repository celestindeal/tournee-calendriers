import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../state/position_controller.dart';

/// Point bleu « vous êtes ici » et cercle de précision (F6).
/// Ne capte pas le toucher : on peut toucher la maison qui est dessous.
class CouchePosition extends StatelessWidget {
  const CouchePosition({super.key, required this.position});

  final PositionController position;

  static const _bleu = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: position,
      builder: (context, _) {
        final p = position.position;
        if (p == null) return const SizedBox.shrink();
        return IgnorePointer(
          child: CircleLayer(
            circles: [
              CircleMarker(
                point: p.point,
                radius: p.precisionM,
                useRadiusInMeter: true,
                color: _bleu.withValues(alpha: 0.12),
                borderColor: _bleu.withValues(alpha: 0.4),
                borderStrokeWidth: 1,
              ),
              CircleMarker(
                point: p.point,
                radius: 8,
                color: _bleu,
                borderColor: Colors.white,
                borderStrokeWidth: 3,
              ),
            ],
          ),
        );
      },
    );
  }
}
