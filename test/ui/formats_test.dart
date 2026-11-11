import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/ui/formats.dart';

void main() {
  final maintenant = DateTime(2026, 11, 15, 20, 0);

  test('décrit un moment de façon lisible', () {
    expect(decrireMoment(DateTime(2026, 11, 15, 18, 32), maintenant), 'aujourd\'hui à 18h32');
    expect(decrireMoment(DateTime(2026, 11, 14, 9, 5), maintenant), 'hier à 9h05');
    expect(decrireMoment(DateTime(2026, 11, 12, 23, 59), maintenant), 'il y a 3 jours');
    expect(decrireMoment(DateTime(2026, 11, 2, 10), maintenant), 'le 2/11/2026');
  });

  test('date courte', () {
    expect(dateCourte(DateTime(2026, 11, 1)), 'le 1/11/2026');
  });
}
