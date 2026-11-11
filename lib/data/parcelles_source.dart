import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/jeu_parcelles.dart';

/// Charge les parcelles embarquées dans l'app.
class ParcellesSource {
  ParcellesSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Doit correspondre à la déclaration `assets:` de pubspec.yaml.
  static const chemin = 'assets/data/parcelles.json';

  final AssetBundle _bundle;

  Future<JeuParcelles> charger() async {
    final texte = await _bundle.loadString(chemin);
    return JeuParcelles.depuisJson(jsonDecode(texte) as Map<String, dynamic>);
  }
}
