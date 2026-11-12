import 'package:flutter/material.dart';

import '../models/parcelle.dart';
import '../models/statut.dart';
import '../state/listes.dart';
import '../state/tournee_controller.dart';
import 'formats.dart';
import 'itineraire.dart';
import 'memos.dart';

/// Listes des maisons « à repasser » et « non visitées », par commune et par
/// rue. Toucher une maison revient sur la carte, centrée sur elle (la page
/// renvoie l'identifiant de la parcelle choisie).
class ListesPage extends StatefulWidget {
  const ListesPage({super.key, required this.controller, this.ongletInitial = 0});

  final TourneeController controller;

  /// 0 = À repasser, 1 = Non visitées.
  final int ongletInitial;

  @override
  State<ListesPage> createState() => _ListesPageState();
}

class _ListesPageState extends State<ListesPage> {
  TourneeController get _c => widget.controller;

  /// Zone affichée : [_maTournee], un code INSEE, ou `null` (toutes les communes).
  /// Par défaut : ma tournée si j'en ai choisi une.
  late String? _commune = _c.maTournee == null ? null : _maTournee;

  static const _maTournee = 'tournee';

  static const _onglets = [Statut.aRepasser, Statut.nonVisite];

  List<Parcelle> _parcelles(Statut statut) => [
        for (final p in _c.jeu.parcelles)
          if (_c.statutDe(p.id) == statut &&
              switch (_commune) {
                null => true,
                _maTournee => _c.estDansMaTournee(p.id),
                final insee => p.codeInsee == insee,
              })
            p,
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final aRepasser = _parcelles(Statut.aRepasser);
        final nonVisitees = _parcelles(Statut.nonVisite);
        return DefaultTabController(
          length: 2,
          initialIndex: widget.ongletInitial,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Listes des maisons'),
              bottom: TabBar(
                tabs: [
                  Tab(key: const Key('onglet-a-repasser'), text: 'À repasser (${aRepasser.length})'),
                  Tab(key: const Key('onglet-non-visitees'), text: 'Non visitées (${nonVisitees.length})'),
                ],
              ),
            ),
            body: Column(
              children: [
                _ChoixCommune(
                  communes: [
                    if (_c.maTournee case final t?) (_maTournee, t.nom),
                    (null, 'Toutes les communes'),
                    for (final c in _c.jeu.communes) (c.insee, c.nom),
                  ],
                  choisie: _commune,
                  onChoix: (insee) => setState(() => _commune = insee),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final (statut, liste) in [(_onglets[0], aRepasser), (_onglets[1], nonVisitees)])
                        _Liste(controller: _c, statut: statut, parcelles: liste, afficherCommune: _commune == null || _commune == _maTournee),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChoixCommune extends StatelessWidget {
  const _ChoixCommune({required this.communes, required this.choisie, required this.onChoix});

  /// (clé, nom) : la clé `null` = toutes les communes.
  final List<(String?, String)> communes;
  final String? choisie;
  final ValueChanged<String?> onChoix;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          for (final (insee, nom) in communes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('commune-${insee ?? 'toutes'}'),
                label: Text(nom),
                selected: choisie == insee,
                onSelected: (_) => onChoix(insee),
              ),
            ),
        ],
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.controller,
    required this.statut,
    required this.parcelles,
    required this.afficherCommune,
  });

  final TourneeController controller;
  final Statut statut;
  final List<Parcelle> parcelles;
  final bool afficherCommune;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (parcelles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            statut == Statut.aRepasser ? 'Aucune maison à repasser.' : 'Toutes les maisons ont été visitées.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Liste à plat : titres de rue (GroupeRue) et maisons (Parcelle).
    final lignes = <Object>[
      for (final g in grouperParRue(parcelles, ordreCommunes: [for (final c in controller.jeu.communes) c.insee])) ...[
        g,
        ...g.parcelles,
      ],
    ];
    final maintenant = DateTime.now();
    return ListView.builder(
      itemCount: lignes.length,
      itemBuilder: (context, i) {
        final ligne = lignes[i];
        if (ligne is GroupeRue) {
          final commune = afficherCommune ? controller.jeu.nomCommune(ligne.insee) : null;
          return Container(
            color: theme.colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              [ligne.rue, ?commune, '${ligne.parcelles.length}'].join(' · '),
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
            ),
          );
        }
        final p = ligne as Parcelle;
        final etat = controller.etatDe(p.id);
        final memos = controller.memosDe(p.id);
        return ListTile(
          key: Key('maison-${p.id}'),
          title: Text(p.adresse ?? 'Adresse inconnue (parcelle de ${p.surfaceM2.round()} m²)'),
          subtitle: (statut == Statut.aRepasser && etat != null) || memos.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (statut == Statut.aRepasser && etat != null)
                      Text('À repasser depuis ${decrireMoment(etat.modifieLe, maintenant)}'),
                    if (memos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: PucesMemos(memos: memos),
                      ),
                  ],
                )
              : null,
          trailing: BoutonItineraire(destination: p.centre, titre: p.adresse),
          // Revient sur la carte, centrée sur cette maison.
          onTap: () => Navigator.pop(context, p.id),
        );
      },
    );
  }
}
