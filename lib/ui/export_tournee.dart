import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/export_service.dart';
import '../journal.dart';
import '../state/tournee_controller.dart';

/// Exporte la tournée : ouvre la feuille de partage d'iOS (« Enregistrer dans
/// Fichiers »), ou télécharge le fichier si le partage est impossible.
/// Renvoie `true` si la sauvegarde a été faite.
///
/// Rien n'est attendu avant l'appel au partage : Safari exige qu'il suive
/// directement le toucher (ARCHITECTURE §7.7).
Future<bool> exporterTournee(BuildContext context, TourneeController controller) async {
  void signaler(String message, {bool erreur = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: erreur ? Theme.of(context).colorScheme.error : null,
    ));
  }

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
    if (resultat.status == ShareResultStatus.dismissed) {
      signaler('Export annulé : aucune sauvegarde n\'a été faite.');
      return false;
    }
    await controller.noterExport(maintenant);
    signaler('Sauvegarde faite : $nom');
    return true;
  } catch (e, pile) {
    Journal.instance.ajouter('Export : $e', pile);
    signaler('L\'export a échoué. Réessayez.', erreur: true);
    return false;
  }
}
