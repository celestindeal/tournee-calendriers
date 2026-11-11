import 'package:flutter/material.dart';

/// Avertissement affiché quand l'app est ouverte dans un onglet Safari :
/// les données y sont séparées de celles de l'app installée et peuvent être
/// effacées par iOS (ARCHITECTURE §7.5).
class ConseilInstallation extends StatelessWidget {
  const ConseilInstallation({super.key, required this.onFermer});

  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
        child: Row(
          children: [
            Icon(Icons.install_mobile, size: 20, color: theme.colorScheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Installez l\'app : Partager → « Sur l\'écran d\'accueil ». '
                'Ce qui est coché dans Safari n\'y sera pas.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onTertiaryContainer),
              ),
            ),
            IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: onFermer),
          ],
        ),
      ),
    );
  }
}
