/// Informations fournies par le navigateur (page Diagnostic, conseil
/// d'installation). Interface pure : l'implémentation web est dans
/// navigateur.dart (importé seulement par main.dart), les tests en simulent une.
abstract interface class Plateforme {
  /// Ouverte depuis l'icône de l'écran d'accueil (et non dans un onglet).
  bool get estAppInstallee;

  /// Description du navigateur (user agent).
  String get navigateur;

  /// Le stockage persistant est-il accordé ?
  Future<bool> stockagePersistant();

  /// État du service worker et de ses caches, en une ligne lisible.
  Future<String> serviceWorker();

  /// Le navigateur (Chrome sur Android) peut installer l'app d'un toucher.
  bool get peutInstaller;

  /// Ouvre la fenêtre d'installation du navigateur. Renvoie vrai si
  /// l'utilisateur a accepté.
  Future<bool> installer();

  /// Appelé quand [peutInstaller] change (invitation reçue, app installée).
  void surChangementInstallation(void Function() rappel);
}

/// Version de l'app : identifiant du commit, fourni au build par le
/// workflow GitHub (`--dart-define=VERSION_APP=…`), « dev » en local.
const versionApp = String.fromEnvironment('VERSION_APP', defaultValue: 'dev');
