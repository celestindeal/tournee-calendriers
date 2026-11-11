import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/data/export_service.dart';
import 'package:tournee_calendriers/models/campagne.dart';
import 'package:tournee_calendriers/models/etat_batiment.dart';
import 'package:tournee_calendriers/models/statut.dart';

void main() {
  final date = DateTime.utc(2026, 11, 15, 17, 32);
  EtatBatiment etat(String id, Statut s) => EtatBatiment(batimentId: id, statut: s, modifieLe: date);
  const ids = {'a', 'b', 'c'};

  String exporter(List<EtatBatiment> etats, {String version = 'v1'}) => ExportService.exporter(
        etats: etats,
        versionBatiments: version,
        campagne: Campagne(debut: date, versionBatiments: version),
        maintenant: date,
      );

  test('nom du fichier daté', () {
    expect(ExportService.nomFichier(DateTime(2026, 11, 15, 9, 5)), 'tournee-2026-11-15-0905.json');
  });

  test('le fichier suit le format de l\'architecture (§4.5)', () {
    final json = jsonDecode(exporter([etat('b', Statut.refus), etat('a', Statut.achete)])) as Map;
    expect(json['format'], 'tournee-calendriers');
    expect(json['versionFormat'], 1);
    expect(json['versionBatiments'], 'v1');
    expect(json['exporteLe'], '2026-11-15T17:32:00.000Z');
    expect(json['etats'], [
      {'id': 'a', 's': 'achete', 't': date.millisecondsSinceEpoch},
      {'id': 'b', 's': 'refus', 't': date.millisecondsSinceEpoch},
    ]);
  });

  test('aller-retour exact', () {
    final etats = [etat('a', Statut.achete), etat('b', Statut.aRepasser), etat('c', Statut.nonConcerne)];
    final r = ExportService.lire(exporter(etats), idsConnus: ids, versionBatiments: 'v1');
    expect(r.etats, unorderedEquals(etats));
    expect(r.ignores, 0);
    expect(r.autreVersionBatiments, isFalse);
    expect(r.exporteLe, date);
  });

  test('les maisons absentes de la carte sont ignorées et comptées', () {
    final texte = exporter([etat('a', Statut.achete), etat('zzz', Statut.refus)]);
    final r = ExportService.lire(texte, idsConnus: ids, versionBatiments: 'v1');
    expect(r.etats.map((e) => e.batimentId), ['a']);
    expect(r.ignores, 1);
  });

  test('sans filtre (restauration), tout est gardé', () {
    final texte = exporter([etat('zzz', Statut.refus)]);
    expect(ExportService.lire(texte, idsConnus: null, versionBatiments: 'v1').etats, hasLength(1));
  });

  test('un fichier fait avec une autre carte est signalé', () {
    final r = ExportService.lire(exporter([etat('a', Statut.achete)], version: 'v0'), idsConnus: ids, versionBatiments: 'v1');
    expect(r.autreVersionBatiments, isTrue);
    expect(r.etats, hasLength(1));
  });

  group('fichiers refusés avec un message lisible', () {
    void refuse(String texte, String debutMessage) {
      expect(
        () => ExportService.lire(texte, idsConnus: ids, versionBatiments: 'v1'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', startsWith(debutMessage))),
      );
    }

    test('pas du JSON', () => refuse('bonjour', 'Ce fichier n\'est pas une sauvegarde'));
    test('un autre JSON', () => refuse('{"a": 1}', 'Ce fichier n\'est pas une sauvegarde'));
    test('version plus récente', () {
      refuse(jsonEncode({'format': 'tournee-calendriers', 'versionFormat': 2, 'etats': []}), 'Ce fichier vient');
    });
    test('statut inconnu', () {
      refuse(
        jsonEncode({
          'format': 'tournee-calendriers',
          'versionFormat': 1,
          'etats': [
            {'id': 'a', 's': 'bizarre', 't': 1},
          ],
        }),
        'Ce fichier de sauvegarde est abîmé',
      );
    });
  });
}
