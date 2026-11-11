import 'package:flutter/material.dart';

import '../models/memo.dart';
import '../state/tournee_controller.dart';

/// Icône d'un mémo (icônes Material, embarquées : pas d'emoji, qui
/// déclencherait un téléchargement de police et casserait le hors-ligne).
/// Les jours de la semaine n'ont pas d'icône (libellé court).
IconData? iconeMemo(Memo memo) => switch (memo) {
      Memo.chien => Icons.pets,
      Memo.pasDeDemarchage => Icons.block,
      Memo.motLaisse => Icons.mail_outline,
      Memo.matin => Icons.wb_sunny_outlined,
      Memo.midi => Icons.lunch_dining_outlined,
      Memo.soir => Icons.nights_stay_outlined,
      Memo.weekend => Icons.weekend_outlined,
      _ => null,
    };

/// Les mémos d'une maison, en petites puces (lecture seule).
class PucesMemos extends StatelessWidget {
  const PucesMemos({super.key, required this.memos});

  final Set<Memo> memos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attention = theme.colorScheme.errorContainer;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final m in Memo.values)
          if (memos.contains(m))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: m.groupe == GroupeMemo.attention ? attention : theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconeMemo(m) != null) ...[Icon(iconeMemo(m), size: 14), const SizedBox(width: 4)],
                  Text(m.etiquette, style: theme.textTheme.labelMedium),
                ],
              ),
            ),
      ],
    );
  }
}

/// Feuille de choix des mémos d'une parcelle : chaque toucher est enregistré.
Future<void> ouvrirFeuilleMemos(BuildContext context, TourneeController controller, String parcelleId,
    {String? titre}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final theme = Theme.of(context);
          final actuels = controller.memosDe(parcelleId);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titre == null ? 'Mémos' : 'Mémos – $titre', style: theme.textTheme.titleMedium),
                for (final groupe in GroupeMemo.values) ...[
                  const SizedBox(height: 14),
                  Text(groupe.titre, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final m in Memo.values.where((m) => m.groupe == groupe))
                        FilterChip(
                          key: Key('memo-${m.name}'),
                          avatar: iconeMemo(m) == null ? null : Icon(iconeMemo(m), size: 18),
                          label: Text(m.libelle),
                          selected: actuels.contains(m),
                          onSelected: (_) => controller.basculerMemo(parcelleId, m),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Terminé')),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
