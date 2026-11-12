/// <reference path="../pb_data/types.d.ts" />

// Serveur de synchronisation de la tournée des calendriers (PocketBase).
//
// À chaque démarrage :
// 1. crée les tables si elles n'existent pas encore ;
// 2. les ouvre aux téléphones qui envoient la clé de synchronisation (en-tête
//    « X-Cle-Synchro »), lu dans la variable d'environnement CLE_SYNCHRO.
//    La clé n'est jamais écrite dans ce dépôt public. Changer la clé =
//    changer la variable et redémarrer.
//
// Pour chaque environnement (production « », test « test_ ») :
//   statuts : un enregistrement par maison (statut de la campagne en cours) ;
//   memos   : un enregistrement par maison.
// Règles :
// - lecture et création : avec la bonne clé ;
// - modification : avec la bonne clé, et seulement si elle est plus récente
//   (champ t) que celle enregistrée : la plus récente gagne ;
// - suppression : jamais depuis les téléphones.

onBootstrap((e) => {
  e.next();
  const app = e.app;

  const cle = $os.getenv("CLE_SYNCHRO");
  if (!/^[A-Za-z0-9-]{12,}$/.test(cle || "")) {
    throw new Error("CLE_SYNCHRO manquant ou trop court (12 caractères minimum : lettres, chiffres, tirets).");
  }
  const acces = `@request.headers.x_cle_synchro = "${cle}"`;

  const existe = (nom) => {
    try {
      app.findCollectionByNameOrId(nom);
      return true;
    } catch (_) {
      return false;
    }
  };
  const dates = [
    { name: "created", type: "autodate", onCreate: true, onUpdate: false },
    { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
  ];

  for (const prefixe of ["", "test_"]) {
    if (!existe(`${prefixe}statuts`)) {
      app.save(new Collection({
        type: "base",
        name: `${prefixe}statuts`,
        fields: [
          { name: "parcelle", type: "text", required: true, max: 40 },
          { name: "campagne", type: "number", required: true, onlyInt: true },
          { name: "statut", type: "text", required: true, max: 20 },
          { name: "t", type: "number", required: true, onlyInt: true },
          { name: "appareil", type: "text", max: 20 },
          ...dates,
        ],
        indexes: [`CREATE INDEX idx_${prefixe}statuts_maj ON ${prefixe}statuts (campagne, updated)`],
      }));
    }
    if (!existe(`${prefixe}memos`)) {
      app.save(new Collection({
        type: "base",
        name: `${prefixe}memos`,
        fields: [
          { name: "parcelle", type: "text", required: true, max: 40 },
          { name: "memos", type: "text", max: 300 },
          { name: "t", type: "number", required: true, onlyInt: true },
          { name: "appareil", type: "text", max: 20 },
          ...dates,
        ],
        indexes: [`CREATE INDEX idx_${prefixe}memos_maj ON ${prefixe}memos (updated)`],
      }));
    }
  }

  // Sert à vérifier la clé de synchronisation : sa liste n'est visible qu'avec la bonne clé.
  if (!existe("acces")) {
    const collection = new Collection({ type: "base", name: "acces", fields: [{ name: "nom", type: "text", max: 40 }] });
    app.save(collection);
    const enregistrement = new Record(collection);
    enregistrement.set("nom", "tournee-calendriers");
    app.save(enregistrement);
  }

  const regles = {
    statuts: `${acces} && @request.body.t > t && @request.body.campagne >= campagne`,
    memos: `${acces} && @request.body.t > t`,
  };
  for (const prefixe of ["", "test_"]) {
    for (const table of ["statuts", "memos"]) {
      const collection = app.findCollectionByNameOrId(prefixe + table);
      collection.listRule = acces;
      collection.viewRule = acces;
      collection.createRule = acces;
      collection.updateRule = regles[table];
      collection.deleteRule = null;
      app.save(collection);
    }
  }
  const collection = app.findCollectionByNameOrId("acces");
  collection.listRule = acces;
  collection.viewRule = acces;
  app.save(collection);

  console.log("Tournée : tables prêtes, clé de synchronisation appliqué.");
});
