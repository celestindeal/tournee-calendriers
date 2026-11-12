import 'package:flutter/material.dart';

import '../platform/systeme.dart';

/// Conseil affiché quand l'app est ouverte dans un onglet du navigateur au
/// lieu de l'app installée (ARCHITECTURE §7.5) :
/// - iPhone : l'onglet Safari a des données SÉPARÉES de l'app installée, que
///   iOS peut effacer ;
/// - Android : Chrome peut installer l'app d'un toucher (bouton « Installer »),
///   les données sont les mêmes que dans Chrome.
class ConseilInstallation extends StatelessWidget {
  const ConseilInstallation({
    super.key,
    required this.systeme,
    required this.onFermer,
    this.onInstaller,
  });

  final Systeme systeme;
  final VoidCallback onFermer;

  /// Installer d'un toucher (fourni seulement si le navigateur le propose).
  final VoidCallback? onInstaller;

  String get _texte => switch (systeme) {
    Systeme.ios =>
      'Installez l\'app : Partager → « Sur l\'écran d\'accueil ». '
          'Ce qui est coché dans Safari n\'y sera pas.',
    _ when onInstaller != null => 'Installez l\'app sur l\'écran d\'accueil : elle marchera aussi sans réseau.',
    Systeme.android =>
      'Installez l\'app : menu ⋮ de Chrome → « Installer l\'application » '
          '(ou « Ajouter à l\'écran d\'accueil »).',
    Systeme.autre => 'Installez l\'app depuis le menu du navigateur (« Installer » ou « Ajouter à l\'écran d\'accueil »).',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = theme.colorScheme.onTertiaryContainer;
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
        child: Row(
          children: [
            Icon(Icons.install_mobile, size: 20, color: couleur),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _texte,
                key: const Key('texte-installation'),
                style: theme.textTheme.bodySmall?.copyWith(color: couleur),
              ),
            ),
            if (onInstaller != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilledButton(
                  key: const Key('bouton-installer'),
                  onPressed: onInstaller,
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Installer'),
                ),
              ),
            IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: onFermer),
          ],
        ),
      ),
    );
  }
}
