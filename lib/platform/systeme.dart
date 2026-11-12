/// Système du téléphone, pour adapter les explications et les choix proposés
/// (Plans d'Apple seulement sur iPhone, réglages de localisation…).
enum Systeme {
  ios,
  android,
  autre;

  /// Déduit du « user agent » du navigateur.
  static Systeme detecter(String userAgent) {
    final ua = userAgent.toLowerCase();
    if (ua.contains('android')) return android;
    // iPadOS se présente comme un Mac : on le reconnaît à « Mobile ».
    if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod') ||
        (ua.contains('macintosh') && ua.contains('mobile'))) {
      return ios;
    }
    return autre;
  }
}

/// Système de ce téléphone, réglé au démarrage par main.dart (« autre »
/// dans les tests).
Systeme systemeCourant = Systeme.autre;
