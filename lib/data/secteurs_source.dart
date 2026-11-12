import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/secteur.dart';

/// Charge les contours des tournées embarqués dans l'app.
class SecteursSource {
  SecteursSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Doit correspondre à la déclaration `assets:` de pubspec.yaml.
  static const chemin = 'assets/data/tournees.json';

  final AssetBundle _bundle;

  Future<List<Secteur>> charger() async =>
      Secteur.listeDepuisJson(jsonDecode(await _bundle.loadString(chemin)) as Map<String, dynamic>);
}
