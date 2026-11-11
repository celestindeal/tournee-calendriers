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
}

/// Version de l'app : identifiant du commit, fourni au build par le
/// workflow GitHub (`--dart-define=VERSION_APP=…`), « dev » en local.
const versionApp = String.fromEnvironment('VERSION_APP', defaultValue: 'dev');
