import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/filtre.dart';
import '../models/jeu_parcelles.dart';
import '../models/secteur.dart';
import '../platform/plateforme.dart';
import '../state/position_controller.dart';
import '../state/tournee_controller.dart';
import 'barre_avancement.dart';
import 'conseil_installation.dart';
import 'couche_parcelles.dart';
import 'couche_position.dart';
import 'menu_page.dart';
import 'panneau_statut.dart';
import 'recherche_page.dart';

/// Écran principal : carte, compteur en haut, panneau de statut en bas,
/// bouton « Me localiser ».
class CartePage extends StatefulWidget {
  const CartePage({
    super.key,
    required this.controller,
    required this.position,
    required this.plateforme,
  });

  final TourneeController controller;
  final PositionController position;
  final Plateforme plateforme;

  @override
  State<CartePage> createState() => _CartePageState();
}

class _CartePageState extends State<CartePage> {
  TourneeController get _controller => widget.controller;
  PositionController get _position => widget.position;

  final _carte = MapController();
  late final AppLifecycleListener _cycleDeVie;

  /// Conseil « installez l'app » si elle est ouverte dans un onglet (ARCHITECTURE §7.5).
  late bool _conseilVisible = !widget.plateforme.estAppInstallee;

  /// Recentrer la carte dès la première position reçue après « Me localiser ».
  bool _recentrerAuProchainPoint = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_afficherErreur);
    _controller.addListener(_surChangementDeTournee);
    _position.addListener(_surPosition);
    // GPS coupé en arrière-plan (batterie), relancé au retour (ARCHITECTURE §7.6).
    _cycleDeVie = AppLifecycleListener(
      onHide: _position.mettreEnPause,
      onShow: () {
        _position.reprendre();
        // Au retour dans l'app : récupérer tout de suite ce que les autres ont fait.
        _controller.synchro?.synchroniser();
      },
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_afficherErreur);
    _controller.removeListener(_surChangementDeTournee);
    _position.removeListener(_surPosition);
    _cycleDeVie.dispose();
    _carte.dispose();
    super.dispose();
  }

  void _signaler(String message, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: erreur ? Theme.of(context).colorScheme.error : null,
    ));
  }

  /// Tournée affichée au dernier passage (pour recentrer quand elle change).
  late Secteur? _tourneeAffichee = _controller.maTournee;

  void _surChangementDeTournee() {
    final t = _controller.maTournee;
    if (identical(t, _tourneeAffichee)) return;
    _tourneeAffichee = t;
    if (t != null) _carte.fitCamera(_cadrage(t));
  }

  /// Cadre la carte sur toute la tournée.
  static CameraFit _cadrage(Secteur t) => CameraFit.bounds(
    bounds: LatLngBounds(t.emprise.sudOuest, t.emprise.nordEst),
    padding: const EdgeInsets.fromLTRB(24, 110, 24, 40),
  );

  void _afficherErreur() {
    final message = _controller.derniereErreur;
    if (message == null) return;
    _controller.effacerErreur();
    _signaler(message, erreur: true);
  }

  void _surPosition() {
    final message = _position.message;
    if (message != null) {
      _position.effacerMessage();
      _signaler(message, erreur: _position.etat == EtatGps.refuse);
    }
    final p = _position.position;
    if (_recentrerAuProchainPoint && p != null) {
      _recentrerAuProchainPoint = false;
      _recentrer(p);
    }
  }

  void _meLocaliser() {
    final p = _position.position;
    if (p != null) {
      _recentrer(p);
    } else {
      _recentrerAuProchainPoint = true;
    }
    _position.demarrer();
  }

  void _recentrer(PositionGps p) => _carte.move(p.point, max(_carte.camera.zoom, 17));

  /// Menu (listes, affichage, campagne, sauvegarde…). Une maison choisie dans
  /// les listes du menu est centrée sur la carte, panneau ouvert.
  Future<void> _ouvrirMenu() =>
      _allerALaMaisonChoisie(MenuPage(controller: _controller, plateforme: widget.plateforme));

  /// Recherche d'adresse ; même retour sur la carte que les listes.
  Future<void> _ouvrirRecherche() => _allerALaMaisonChoisie(RecherchePage(controller: _controller));

  Future<void> _allerALaMaisonChoisie(Widget page) async {
    final id = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => page));
    final parcelle = id == null ? null : _controller.parcelle(id);
    if (parcelle == null || !mounted) return;
    // La maison doit être visible : sinon on enlève le filtre.
    if (!_controller.estVisible(id!)) _controller.changerFiltre(Filtre.toutes);
    // La maison est placée au-dessus du milieu de l'écran, pour ne pas être
    // cachée par le panneau qui s'ouvre en bas.
    _carte.move(parcelle.centre, max(_carte.camera.zoom, 17), offset: const Offset(0, -110));
    _controller.selectionner(id);
  }

  @override
  Widget build(BuildContext context) {
    final jeu = _controller.jeu;
    final emprise = LatLngBounds(jeu.sudOuest, jeu.nordEst);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _carte,
            options: MapOptions(
              // Vue de départ : le bourg de la première commune (Saint-Héand),
              // assez zoomée pour voir et toucher les maisons. On rejoint les
              // autres communes en déplaçant la carte (ou avec « Me localiser »).
              initialCenter: _centreDepart(jeu),
              initialZoom: 15,
              // Avec une tournée choisie : la carte s'ouvre dessus.
              initialCameraFit: _controller.maTournee == null ? null : _cadrage(_controller.maTournee!),
              cameraConstraint: CameraConstraint.containCenter(bounds: emprise),
              minZoom: 12,
              maxZoom: 19,
              // Fond neutre quand les tuiles ne se chargent pas (hors-ligne).
              backgroundColor: const Color(0xFFEDEDED),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              // Toucher à côté des bâtiments : ferme le panneau.
              onTap: (_, _) => _controller.selectionner(null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.amicale.tournee_calendriers',
                maxNativeZoom: 19,
                keepBuffer: 1,
                panBuffer: 0,
              ),
              CoucheParcelles(controller: _controller),
              CouchePosition(position: _position),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  const TextSourceAttribution('Contributeurs OpenStreetMap'),
                  for (final source in jeu.sources) TextSourceAttribution(source),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              minimum: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BarreAvancement(
                    controller: _controller,
                    onMenu: _ouvrirMenu,
                    onRecherche: _ouvrirRecherche,
                    estTest: !estProduction,
                  ),
                  IndicateurFiltre(controller: _controller),
                  if (_conseilVisible) ...[
                    const SizedBox(height: 8),
                    ConseilInstallation(onFermer: () => setState(() => _conseilVisible = false)),
                  ],
                ],
              ),
            ),
          ),
          // Bouton « Me localiser », caché quand le panneau de statut est ouvert.
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: ListenableBuilder(
                listenable: Listenable.merge([_controller, _position]),
                builder: (context, _) {
                  if (_controller.selection != null) return const SizedBox.shrink();
                  return FloatingActionButton(
                    key: const Key('bouton-gps'),
                    tooltip: 'Me localiser',
                    onPressed: _meLocaliser,
                    child: _IconeGps(_position.etat),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final selection = _controller.selection;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  // Le panneau glisse depuis le bas de l'écran.
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                  child: selection == null
                      ? const SizedBox.shrink()
                      : PanneauStatut(
                          key: ValueKey(selection.id),
                          controller: _controller,
                          parcelle: selection,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Centre moyen des parcelles de la première commune : tombe dans le bourg,
/// là où les maisons sont les plus denses.
LatLng _centreDepart(JeuParcelles jeu) {
  final insee = jeu.communes.first.insee;
  final parcelles = jeu.parcelles.where((p) => p.codeInsee == insee).toList();
  if (parcelles.isEmpty) return jeu.centre;
  var lat = 0.0, lon = 0.0;
  for (final p in parcelles) {
    lat += p.centre.latitude;
    lon += p.centre.longitude;
  }
  return LatLng(lat / parcelles.length, lon / parcelles.length);
}

class _IconeGps extends StatelessWidget {
  const _IconeGps(this.etat);

  final EtatGps etat;

  @override
  Widget build(BuildContext context) => switch (etat) {
        EtatGps.arrete => const Icon(Icons.location_searching),
        EtatGps.recherche => const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        EtatGps.actif => const Icon(Icons.my_location),
        EtatGps.refuse => const Icon(Icons.location_disabled),
        EtatGps.indisponible => const Icon(Icons.gps_not_fixed),
      };
}
