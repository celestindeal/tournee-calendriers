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
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Icon(Icons.install_mobile, color: theme.colorScheme.onTertiaryContainer),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Installez l\'app avant la tournée : dans Safari, touchez Partager, '
                  'puis « Sur l\'écran d\'accueil ». Ouvrez-la ensuite toujours depuis '
                  'son icône : les maisons cochées ici, dans Safari, n\'y seront pas.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer),
                ),
              ),
            ),
            IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: onFermer),
          ],
        ),
      ),
    );
  }
}
