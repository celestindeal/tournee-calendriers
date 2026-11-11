import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/export_service.dart';
import '../journal.dart';
import '../models/filtre.dart';
import '../models/statut.dart';
import '../platform/plateforme.dart';
import '../state/tournee_controller.dart';
import 'barre_avancement.dart';
import 'diagnostic_page.dart';
import 'export_tournee.dart';
import 'formats.dart';
import 'listes_page.dart';
import 'nouvelle_campagne_page.dart';
import 'recherche_page.dart';
import 'synchro_page.dart';
import '../synchro/synchro_controller.dart';

/// Menu et réglages : listes des maisons, affichage (filtre F9, légende),
/// campagne (F11), sauvegarde (export / import, F8), diagnostic, sources.
/// Peut renvoyer à la carte l'identifiant d'une maison choisie dans une liste.
class MenuPage extends StatelessWidget {
  const MenuPage({super.key, required this.controller, required this.plateforme});

  final TourneeController controller;
  final Plateforme plateforme;

  void _signaler(BuildContext context, String message, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: erreur ? Theme.of(context).colorScheme.error : null),
    );
  }

  Future<void> _exporter(BuildContext context) => exporterTournee(context, controller);

  Future<void> _ouvrirListes(BuildContext context, int onglet) =>
      _ouvrirAutrePage(context, ListesPage(controller: controller, ongletInitial: onglet));

  /// Ouvre une page qui peut renvoyer une maison (listes, recherche) : le
  /// menu se ferme alors en la renvoyant à la carte, qui se centre dessus.
  Future<void> _ouvrirAutrePage(BuildContext context, Widget page) async {
    final id = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => page));
    if (id != null && context.mounted) Navigator.pop(context, id);
  }

  Future<void> _importer(BuildContext context) async {
    final PlatformFile? fichier;
    try {
      // Tous types de fichiers : iOS grise parfois les .json si on filtre.
      fichier = await FilePicker.pickFile(type: FileType.any);
    } catch (e, pile) {
      Journal.instance.ajouter('Import (choix du fichier) : $e', pile);
      if (context.mounted) _signaler(context, 'Impossible d\'ouvrir le fichier.', erreur: true);
      return;
    }
    if (fichier == null || !context.mounted) return;

    final ResultatImport resultat;
    try {
      resultat = controller.lireImport(await fichier.xFile.readAsString());
    } on FormatException catch (e) {
      if (context.mounted) await _alerte(context, 'Import impossible', e.message);
      return;
    } catch (e, pile) {
      Journal.instance.ajouter('Import (lecture) : $e', pile);
      if (context.mounted) await _alerte(context, 'Import impossible', 'Le fichier n\'a pas pu être lu.');
      return;
    }
    if (!context.mounted) return;

    final quand = resultat.exporteLe == null
        ? ''
        : ' (sauvegarde ${decrireMoment(resultat.exporteLe!, DateTime.now())})';
    final confirme = await _confirmer(
      context,
      titre: 'Remplacer la tournée ?',
      texte: [
        'Le fichier$quand contient ${resultat.etats.length} statut(s). '
            'Ils vont remplacer les ${controller.nbEtatsEnregistres} statut(s) actuels.',
        if (resultat.ignores > 0)
          '${resultat.ignores} maison(s) du fichier n\'existent pas sur la carte : elles seront ignorées.',
        if (resultat.autreVersionCarte) 'Attention : ce fichier a été fait avec une autre version de la carte.',
        'Vous pourrez annuler cet import depuis ce menu.',
      ].join('\n\n'),
      action: 'Remplacer',
    );
    if (confirme != true) return;

    try {
      await controller.importer(resultat);
      if (context.mounted) _signaler(context, 'Import terminé : ${resultat.etats.length} statut(s).');
    } catch (e, pile) {
      Journal.instance.ajouter('Import (écriture) : $e', pile);
      if (context.mounted) _signaler(context, 'L\'import a échoué : rien n\'a été modifié.', erreur: true);
    }
  }

  Future<void> _annulerImport(BuildContext context) async {
    final confirme = await _confirmer(
      context,
      titre: 'Annuler le dernier import ?',
      texte:
          'La tournée revient à son état d\'avant l\'import. '
          'Les maisons cochées depuis l\'import seront perdues.',
      action: 'Annuler l\'import',
    );
    if (confirme != true) return;
    try {
      await controller.annulerDernierImport();
      if (context.mounted) _signaler(context, 'Import annulé.');
    } catch (e, pile) {
      Journal.instance.ajouter('Annulation d\'import : $e', pile);
      if (context.mounted) _signaler(context, 'L\'annulation a échoué.', erreur: true);
    }
  }

  Future<void> _alerte(BuildContext context, String titre, String texte) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titre),
      content: Text(texte),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );

  Future<bool?> _confirmer(
    BuildContext context, {
    required String titre,
    required String texte,
    required String action,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titre),
      content: Text(texte),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final dernier = controller.dernierExport;
          final maintenant = DateTime.now();
          final exportEnRetard =
              controller.nbEtatsEnregistres > 0 &&
              (dernier == null || maintenant.difference(dernier) > const Duration(days: 2));
          final campagne = controller.campagne;
          final nbARepasser = controller.avancement.aRepasser;
          final nbNonVisitees = controller.jeu.parcelles
              .where((p) => controller.statutDe(p.id) == Statut.nonVisite)
              .length;
          return ListView(
            children: [
              const _Titre('Maisons'),
              ListTile(
                key: const Key('menu-a-repasser'),
                leading: Icon(Icons.replay, color: Statut.aRepasser.couleur),
                title: Text('À repasser ($nbARepasser)'),
                subtitle: const Text('Liste par commune et par rue'),
                onTap: () => _ouvrirListes(context, 0),
              ),
              ListTile(
                key: const Key('menu-non-visitees'),
                leading: const Icon(Icons.format_list_bulleted),
                title: Text('Non visitées ($nbNonVisitees)'),
                subtitle: const Text('Liste par commune et par rue'),
                onTap: () => _ouvrirListes(context, 1),
              ),
              ListTile(
                key: const Key('menu-recherche'),
                leading: const Icon(Icons.search),
                title: const Text('Rechercher une adresse'),
                onTap: () => _ouvrirAutrePage(context, RecherchePage(controller: controller)),
              ),
              const Divider(),
              const _Titre('Affichage sur la carte'),
              for (final f in Filtre.values)
                ListTile(
                  key: Key('filtre-${f.name}'),
                  leading: Icon(
                    f == controller.filtre ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: f == controller.filtre ? theme.colorScheme.primary : null,
                  ),
                  title: Text(switch (f) {
                    Filtre.toutes => 'Toutes les maisons',
                    Filtre.nonVisitees => 'Seulement les non visitées',
                    Filtre.aRepasser => 'Seulement celles à repasser',
                  }),
                  onTap: () {
                    controller.changerFiltre(f);
                    // Retour direct sur la carte pour voir le résultat.
                    Navigator.pop(context);
                  },
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: LegendeCouleurs(key: Key('legende')),
              ),
              const Divider(),
              if (campagne != null) ...[
                _Titre('Campagne ${campagne.annee}'),
                ListTile(
                  leading: const Icon(Icons.event_note),
                  title: Text('Commencée ${dateCourte(campagne.debut)}'),
                  subtitle: Text(
                    [
                      controller.avancement.resume,
                      for (final a in controller.archives)
                        'Campagne ${a.annee} : ${a.nombre(Statut.achete) + a.nombre(Statut.refus)} faits, '
                            '${a.nombre(Statut.achete)} achetés',
                    ].join('\n'),
                  ),
                ),
                ListTile(
                  key: const Key('menu-nouvelle-campagne'),
                  leading: const Icon(Icons.restart_alt),
                  title: const Text('Nouvelle campagne…'),
                  subtitle: const Text('Archive cette année et remet toutes les maisons à zéro'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => NouvelleCampagnePage(controller: controller)),
                  ),
                ),
                const Divider(),
              ],
              if (controller.synchro case final synchro?) ...[
                const _Titre('Équipe'),
                ListenableBuilder(
                  listenable: synchro,
                  builder: (context, _) => ListTile(
                    key: const Key('menu-synchro'),
                    leading: IconeSynchro(synchro: synchro, taille: 24),
                    title: const Text('Synchronisation'),
                    subtitle: Text(switch (synchro) {
                      SynchroController(active: false) => 'Partager la tournée entre téléphones',
                      SynchroController(nbEnAttente: final n) when n > 0 =>
                        '${synchro.etat.libelle} · $n changement(s) à envoyer',
                      SynchroController(dernierSucces: final d?) =>
                        '${synchro.etat.libelle} · ${decrireMoment(d.toLocal(), maintenant)}',
                      _ => synchro.etat.libelle,
                    }),
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SynchroPage(synchro: synchro))),
                  ),
                ),
                const Divider(),
              ],
              const _Titre('Sauvegarde'),
              ListTile(
                key: const Key('menu-exporter'),
                leading: const Icon(Icons.ios_share),
                title: const Text('Exporter la tournée'),
                subtitle: Text(
                  dernier == null ? 'Jamais exportée' : 'Dernier export : ${decrireMoment(dernier, maintenant)}',
                  style: exportEnRetard ? TextStyle(color: theme.colorScheme.error) : null,
                ),
                onTap: () => _exporter(context),
              ),
              ListTile(
                key: const Key('menu-importer'),
                leading: const Icon(Icons.file_open_outlined),
                title: const Text('Importer une sauvegarde'),
                subtitle: const Text('Remplace les statuts actuels'),
                onTap: () => _importer(context),
              ),
              if (controller.peutAnnulerImport)
                ListTile(
                  key: const Key('menu-annuler-import'),
                  leading: const Icon(Icons.undo),
                  title: const Text('Annuler le dernier import'),
                  onTap: () => _annulerImport(context),
                ),
              const Divider(),
              const _Titre('Application'),
              ListTile(
                key: const Key('menu-diagnostic'),
                leading: const Icon(Icons.troubleshoot),
                title: const Text('Diagnostic'),
                subtitle: const Text('Pour signaler un problème'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DiagnosticPage(controller: controller, plateforme: plateforme),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Sources des données'),
                subtitle: Text(['Fond de carte : contributeurs OpenStreetMap', ...controller.jeu.sources].join('\n')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(texte, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}
