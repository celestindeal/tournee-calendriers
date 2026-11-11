import 'package:flutter/material.dart';

import 'config.dart';
import 'journal.dart';
import 'platform/plateforme.dart';
import 'state/position_controller.dart';
import 'state/tournee_controller.dart';
import 'ui/carte_page.dart';

/// Application : écran de chargement, puis carte (ou message d'erreur).
class TourneeApp extends StatefulWidget {
  const TourneeApp({
    super.key,
    required this.demarrer,
    required this.plateforme,
    required this.position,
  });

  /// Charge les bâtiments et ouvre la base. Fourni par main.dart.
  final Future<TourneeController> Function() demarrer;

  final Plateforme plateforme;
  final PositionController position;

  @override
  State<TourneeApp> createState() => _TourneeAppState();
}

class _TourneeAppState extends State<TourneeApp> {
  late Future<TourneeController> _demarrage = widget.demarrer();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: estProduction ? 'Tournée calendriers' : 'Tournée TEST',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFC62828), // rouge pompiers
        useMaterial3: true,
        fontFamily: 'Roboto', // embarquée, voir pubspec.yaml
      ),
      home: FutureBuilder<TourneeController>(
        future: _demarrage,
        builder: (context, etat) {
          if (etat.hasData) {
            return CartePage(controller: etat.data!, position: widget.position, plateforme: widget.plateforme);
          }
          if (etat.hasError) {
            Journal.instance.ajouter('Démarrage : ${etat.error}', etat.stackTrace);
            return _EcranErreur(
              erreur: etat.error!,
              reessayer: () => setState(() => _demarrage = widget.demarrer()),
            );
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
    );
  }
}

class _EcranErreur extends StatelessWidget {
  const _EcranErreur({required this.erreur, required this.reessayer});

  final Object erreur;
  final VoidCallback reessayer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                'L\'application n\'a pas pu démarrer.\n'
                'Si vous êtes en navigation privée, ouvrez-la depuis l\'icône de l\'écran d\'accueil.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('$erreur', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton(onPressed: reessayer, child: const Text('Réessayer')),
            ],
          ),
        ),
      ),
    );
  }
}
