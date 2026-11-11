import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/jeu_batiments.dart';

/// Charge les bâtiments embarqués dans l'app.
class BatimentsSource {
  BatimentsSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Doit correspondre à la déclaration `assets:` de pubspec.yaml.
  static const chemin = 'assets/data/batiments.json';

  final AssetBundle _bundle;

  Future<JeuBatiments> charger() async {
    final texte = await _bundle.loadString(chemin);
    return JeuBatiments.depuisJson(jsonDecode(texte) as Map<String, dynamic>);
  }
}
