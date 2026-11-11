import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/export_service.dart';
import '../journal.dart';
import '../platform/plateforme.dart';
import '../state/tournee_controller.dart';
import 'diagnostic_page.dart';
import 'formats.dart';

/// Menu : sauvegarde (export / import, F8), diagnostic, sources.
class MenuPage extends StatelessWidget {
  const MenuPage({super.key, required this.controller, required this.plateforme});

  final TourneeController controller;
  final Plateforme plateforme;

  void _signaler(BuildContext context, String message, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: erreur ? Theme.of(context).colorScheme.error : null,
    ));
  }

  /// Ouvre la feuille de partage d'iOS (« Enregistrer dans Fichiers »).
  /// Rien n'est attendu avant l'appel au partage : Safari exige qu'il suive
  /// directement le toucher (ARCHITECTURE §7.7).
  Future<void> _exporter(BuildContext context) async {
    final maintenant = DateTime.now();
    final nom = ExportService.nomFichier(maintenant);
    final fichier = XFile.fromData(
      utf8.encode(controller.contenuExport(maintenant)),
      mimeType: 'application/json',
      name: nom,
    );
    try {
      final resultat = await SharePlus.instance.share(ShareParams(
        files: [fichier],
        fileNameOverrides: [nom],
        title: 'Sauvegarde de la tournée',
        downloadFallbackEnabled: true, // si le partage est impossible : téléchargement
      ));
      if (!context.mounted) return;
      if (resultat.status == ShareResultStatus.dismissed) {
        _signaler(context, 'Export annulé : aucune sauvegarde n\'a été faite.');
        return;
      }
      await controller.noterExport(maintenant);
      if (context.mounted) _signaler(context, 'Sauvegarde faite : $nom');
    } catch (e, pile) {
      Journal.instance.ajouter('Export : $e', pile);
      if (context.mounted) _signaler(context, 'L\'export a échoué. Réessayez.', erreur: true);
    }
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

    final quand = resultat.exporteLe == null ? '' : ' (sauvegarde ${decrireMoment(resultat.exporteLe!, DateTime.now())})';
    final confirme = await _confirmer(
      context,
      titre: 'Remplacer la tournée ?',
      texte: [
        'Le fichier$quand contient ${resultat.etats.length} statut(s). '
            'Ils vont remplacer les ${controller.nbEtatsEnregistres} statut(s) actuels.',
        if (resultat.ignores > 0)
          '${resultat.ignores} maison(s) du fichier n\'existent pas sur la carte : elles seront ignorées.',
        if (resultat.autreVersionBatiments) 'Attention : ce fichier a été fait avec une autre version de la carte.',
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
      texte: 'La tournée revient à son état d\'avant l\'import. '
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

  Future<bool?> _confirmer(BuildContext context,
          {required String titre, required String texte, required String action}) =>
      showDialog<bool>(
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
          final exportEnRetard = controller.nbEtatsEnregistres > 0 &&
              (dernier == null || maintenant.difference(dernier) > const Duration(days: 2));
          return ListView(
            children: [
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
