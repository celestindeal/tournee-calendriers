import '../models/memo.dart';
import '../models/statut.dart';

enum TypeChangement { statut, memos }

/// Une modification d'une maison, échangée avec le serveur : le statut d'une
/// campagne, ou les mémos. Comme sur le téléphone : un id, une valeur, une
/// date (RGPD). Entre deux versions, la plus récente ([t]) gagne.
class Changement {
  Changement.statut({required this.parcelleId, required int this.campagne, required Statut statut, required this.t})
    : type = TypeChangement.statut,
      valeur = statut.name;

  Changement.memos({required this.parcelleId, required Set<Memo> memos, required this.t})
    : type = TypeChangement.memos,
      campagne = null,
      valeur = Memo.versNoms(memos).join(',');

  const Changement._(this.type, this.parcelleId, this.campagne, this.valeur, this.t);

  final TypeChangement type;
  final String parcelleId;

  /// Année de la campagne (statuts seulement).
  final int? campagne;

  /// Nom du statut, ou noms des mémos séparés par des virgules ('' = aucun).
  final String valeur;

  /// Date de la modification, en millisecondes depuis 1970 (UTC).
  final int t;

  /// Identifie ce qui est modifié (une valeur plus récente remplace l'autre).
  String get cle => type == TypeChangement.statut ? 's:$campagne:$parcelleId' : 'm:$parcelleId';

  /// Statut, ou `null` si le nom est inconnu (version plus récente de l'app).
  Statut? get statut => type == TypeChangement.statut ? Statut.depuisNom(valeur) : null;

  Set<Memo> get memos => valeur.isEmpty ? <Memo>{} : Memo.depuisNoms(valeur.split(','));

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(t, isUtc: true);

  Map<String, Object?> versJson() => {
    'type': type.name,
    'id': parcelleId,
    if (campagne != null) 'campagne': campagne,
    'v': valeur,
    't': t,
  };

  /// `null` si l'enregistrement est illisible.
  static Changement? depuisJson(Map<String, Object?> json) {
    final type = TypeChangement.values.asNameMap()[json['type']];
    final id = json['id'];
    final v = json['v'];
    final t = json['t'];
    final campagne = json['campagne'];
    if (type == null || id is! String || v is! String || t is! int) return null;
    if (type == TypeChangement.statut && campagne is! int) return null;
    return Changement._(type, id, campagne as int?, v, t);
  }

  /// Construit un changement reçu du serveur (déjà vérifié par l'appelant).
  factory Changement.recu({
    required TypeChangement type,
    required String parcelleId,
    int? campagne,
    required String valeur,
    required int t,
  }) => Changement._(type, parcelleId, campagne, valeur, t);

  @override
  bool operator ==(Object other) =>
      other is Changement &&
      other.type == type &&
      other.parcelleId == parcelleId &&
      other.campagne == campagne &&
      other.valeur == valeur &&
      other.t == t;

  @override
  int get hashCode => Object.hash(type, parcelleId, campagne, valeur, t);

  @override
  String toString() => 'Changement($cle = $valeur @ $t)';
}
