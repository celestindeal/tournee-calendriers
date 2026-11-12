import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../journal.dart';
import '../platform/systeme.dart';

/// Applications de navigation proposées pour aller jusqu'à une maison.
enum AppliNavigation {
  plans('Plans (Apple)'),
  googleMaps('Google Maps'),
  waze('Waze');

  const AppliNavigation(this.libelle);
  final String libelle;

  /// Applications proposées : Plans d'Apple n'existe pas sur Android.
  static List<AppliNavigation> pour(Systeme systeme) => switch (systeme) {
    Systeme.android => const [googleMaps, waze],
    _ => values,
  };

  /// Lien d'itinéraire vers [destination]. Sur iPhone, ces liens ouvrent
  /// l'application correspondante si elle est installée (Plans l'est toujours),
  /// sinon sa version web. On donne les coordonnées du bâtiment plutôt que
  /// l'adresse : c'est plus précis, et ça marche aussi sans adresse connue.
  Uri lien(LatLng destination) {
    final ll = '${destination.latitude.toStringAsFixed(6)},${destination.longitude.toStringAsFixed(6)}';
    return switch (this) {
      plans => Uri.https('maps.apple.com', '/', {'daddr': ll, 'dirflg': 'd'}),
      googleMaps => Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': ll, 'travelmode': 'driving'}),
      waze => Uri.https('waze.com', '/ul', {'ll': ll, 'navigate': 'yes'}),
    };
  }
}

/// Bouton « itinéraire » : propose Plans (iPhone), Google Maps ou Waze.
class BoutonItineraire extends StatelessWidget {
  const BoutonItineraire({super.key, required this.destination, this.titre});

  final LatLng destination;

  /// Rappelé en haut du menu (l'adresse, si elle est connue).
  final String? titre;

  Future<void> _choisir(BuildContext context) async {
    final appli = await showModalBottomSheet<AppliNavigation>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                titre == null ? 'Itinéraire' : 'Itinéraire vers $titre',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            for (final a in AppliNavigation.pour(systemeCourant))
              ListTile(
                key: Key('itineraire-${a.name}'),
                leading: const Icon(Icons.navigation_outlined),
                title: Text(a.libelle),
                onTap: () => Navigator.pop(context, a),
              ),
          ],
        ),
      ),
    );
    if (appli == null) return;
    try {
      // Nouvel onglet / application externe : l'app de la tournée reste ouverte.
      final ouvert = await launchUrl(appli.lien(destination), mode: LaunchMode.externalApplication);
      if (!ouvert && context.mounted) _erreur(context, appli);
    } catch (e, pile) {
      Journal.instance.ajouter('Itinéraire ${appli.name} : $e', pile);
      if (context.mounted) _erreur(context, appli);
    }
  }

  void _erreur(BuildContext context, AppliNavigation appli) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Impossible d\'ouvrir ${appli.libelle}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('bouton-itineraire'),
      tooltip: 'Itinéraire',
      icon: const Icon(Icons.directions),
      color: Theme.of(context).colorScheme.primary,
      onPressed: () => _choisir(context),
    );
  }
}
