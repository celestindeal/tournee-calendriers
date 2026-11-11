String _d(int n) => n.toString().padLeft(2, '0');

/// « le 11/11/2026 » (heure locale).
String dateCourte(DateTime date) {
  final l = date.toLocal();
  return 'le ${l.day}/${_d(l.month)}/${l.year}';
}

/// « aujourd'hui à 18h32 », « hier à 9h05 », « il y a 3 jours », « le 2/11/2026 ».
String decrireMoment(DateTime date, DateTime maintenant) {
  final l = date.toLocal();
  final m = maintenant.toLocal();
  // Arrondi : un changement d'heure (été/hiver) ne fausse pas le nombre de jours.
  final jours = (DateTime(m.year, m.month, m.day).difference(DateTime(l.year, l.month, l.day)).inHours / 24).round();
  final heure = '${l.hour}h${_d(l.minute)}';
  if (jours <= 0) return 'aujourd\'hui à $heure';
  if (jours == 1) return 'hier à $heure';
  if (jours < 7) return 'il y a $jours jours';
  return dateCourte(date);
}
