import 'package:flutter/foundation.dart';

/// Les dernières erreurs de l'app, affichées dans la page Diagnostic.
///
/// Sans Mac, on ne peut pas lire la console de Safari sur l'iPhone
/// (ARCHITECTURE §7.10) : ce journal en tient lieu. Il est en mémoire
/// seulement (vidé à chaque redémarrage de l'app).
class Journal {
  Journal._();

  static final instance = Journal._();
  static const taille = 50;

  final List<String> _lignes = [];

  /// Les plus récentes d'abord.
  List<String> get lignes => List.unmodifiable(_lignes.reversed);

  void ajouter(Object erreur, [StackTrace? pile]) {
    final maintenant = DateTime.now();
    String d(int n) => n.toString().padLeft(2, '0');
    final heure = '${d(maintenant.hour)}:${d(maintenant.minute)}:${d(maintenant.second)}';
    final ou = pile
        ?.toString()
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
        .trim();
    _lignes.add('$heure  $erreur${ou == null || ou.isEmpty ? '' : '\n    $ou'}');
    if (_lignes.length > taille) _lignes.removeAt(0);
    debugPrint('Journal : $erreur');
  }

  @visibleForTesting
  void vider() => _lignes.clear();
}
