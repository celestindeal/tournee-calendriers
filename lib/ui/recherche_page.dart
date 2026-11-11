import 'package:flutter/material.dart';

import '../models/parcelle.dart';
import '../state/recherche.dart';
import '../state/tournee_controller.dart';
import 'itineraire.dart';
import 'memos.dart';

/// Recherche d'une adresse. Toucher un résultat revient sur la carte, centrée
/// sur la maison (la page renvoie l'identifiant de la parcelle choisie).
/// Le texte tapé n'est jamais enregistré.
class RecherchePage extends StatefulWidget {
  const RecherchePage({super.key, required this.controller});

  final TourneeController controller;

  @override
  State<RecherchePage> createState() => _RecherchePageState();
}

class _RecherchePageState extends State<RecherchePage> {
  TourneeController get _c => widget.controller;

  /// Au-delà, on demande de préciser (la liste resterait illisible).
  static const _maxResultats = 100;

  final _champ = TextEditingController();
  late final IndexAdresses _index = IndexAdresses(
    _c.jeu.parcelles,
    nomCommune: _c.jeu.nomCommune,
    ordreCommunes: [for (final c in _c.jeu.communes) c.insee],
  );

  List<Parcelle> _resultats = const [];

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  void _chercher(String texte) => setState(() => _resultats = _index.chercher(texte));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saisie = _champ.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('champ-recherche'),
          controller: _champ,
          autofocus: true,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: 'Numéro, rue, commune…',
            border: InputBorder.none,
            suffixIcon: saisie
                ? IconButton(
                    key: const Key('effacer-recherche'),
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _champ.clear();
                      _chercher('');
                    },
                  )
                : null,
          ),
          onChanged: _chercher,
        ),
      ),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          if (!saisie) {
            return _Message(
              'Tapez le début d\'une adresse, par exemple « 12 prevert » ou « eglise fouillouse ».\n'
              'Les accents et majuscules ne comptent pas.',
            );
          }
          if (_resultats.isEmpty) return const _Message('Aucune adresse trouvée.');
          final affiches = _resultats.take(_maxResultats).toList();
          final enTrop = _resultats.length - affiches.length;
          return ListView.builder(
            itemCount: affiches.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Text(
                    enTrop > 0
                        ? '${_resultats.length} adresses : précisez la recherche (les $_maxResultats premières sont affichées).'
                        : _resultats.length == 1
                            ? '1 adresse'
                            : '${_resultats.length} adresses',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              return _Resultat(controller: _c, parcelle: affiches[i - 1]);
            },
          );
        },
      ),
    );
  }
}

class _Resultat extends StatelessWidget {
  const _Resultat({required this.controller, required this.parcelle});

  final TourneeController controller;
  final Parcelle parcelle;

  @override
  Widget build(BuildContext context) {
    final p = parcelle;
    final statut = controller.statutDe(p.id);
    final memos = controller.memosDe(p.id);
    final commune = controller.jeu.nomCommune(p.codeInsee);
    return ListTile(
      key: Key('resultat-${p.id}'),
      leading: Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(color: statut.couleur, borderRadius: BorderRadius.circular(4)),
      ),
      minLeadingWidth: 16,
      title: Text(p.adresse!),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text([statut.libelle, ?commune].join(' · ')),
          if (memos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: PucesMemos(memos: memos),
            ),
        ],
      ),
      trailing: BoutonItineraire(destination: p.centre, titre: p.adresse),
      onTap: () => Navigator.pop(context, p.id),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(texte, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
      );
}
