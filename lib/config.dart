/// Environnement de l'app, choisi à la compilation :
///   --dart-define=ENV=prod  (app de la tournée, branche main)
///   --dart-define=ENV=test  (essais, branche test, …/tournee-calendriers/test/)
///
/// Par défaut : production. Ainsi, un build sans réglage garde la base de
/// données de la production et n'en fait jamais « disparaître » les statuts.
const environnement = String.fromEnvironment('ENV', defaultValue: 'prod');

bool get estProduction => environnement == 'prod';

/// Nom de la base IndexedDB. La production garde le nom d'origine
/// (« tournee.db ») : c'est là que sont les statuts déjà saisis.
String get nomBase => estProduction ? 'tournee.db' : 'tournee-$environnement.db';

/// Synchronisation entre téléphones intégrée à l'app : adresse du serveur et
/// clé, fournies à la construction par GitHub (secrets SYNCHRO_ADRESSE et
/// SYNCHRO_CLE, jamais écrits dans le dépôt). Vides = pas de synchronisation.
const synchroAdresse = String.fromEnvironment('SYNCHRO_ADRESSE');
const synchroCle = String.fromEnvironment('SYNCHRO_CLE');

bool get synchroIntegree => synchroAdresse.isNotEmpty && synchroCle.isNotEmpty;
