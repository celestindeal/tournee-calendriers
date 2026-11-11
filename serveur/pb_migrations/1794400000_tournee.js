/// <reference path="../pb_data/types.d.ts" />

// Tables de la synchronisation entre téléphones (serveur PocketBase de la
// Raspberry Pi). Exécuté une seule fois par PocketBase au démarrage.
//
// Le code d'équipe n'est pas écrit ici (le dépôt GitHub est public) : il est
// lu dans la variable d'environnement CODE_EQUIPE au premier démarrage.
// Les téléphones l'envoient dans l'en-tête « X-Code-Equipe » ; sans le bon
// code, le serveur ne montre ni n'accepte rien.
//
// Pour chaque environnement (production « », test « test_ ») :
//   statuts : un enregistrement par maison et par campagne en cours ;
//   memos   : un enregistrement par maison.
// Une modification n'est acceptée que si elle est plus récente (champ t,
// en millisecondes) que celle déjà enregistrée : la plus récente gagne.
// Rien ne peut être supprimé depuis les téléphones.

migrate((app) => {
  const code = $os.getenv("CODE_EQUIPE");
  if (!/^[A-Za-z0-9-]{12,}$/.test(code || "")) {
    throw new Error("CODE_EQUIPE manquant ou trop court (12 caractères minimum : lettres, chiffres, tirets).");
  }
  const acces = `@request.headers.x_code_equipe = "${code}"`;

  const dates = [
    { name: "created", type: "autodate", onCreate: true, onUpdate: false },
    { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
  ];

  for (const prefixe of ["", "test_"]) {
    app.save(new Collection({
      type: "base",
      name: `${prefixe}statuts`,
      listRule: acces,
      viewRule: acces,
      createRule: acces,
      updateRule: `${acces} && @request.body.t > t && @request.body.campagne >= campagne`,
      deleteRule: null,
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

    app.save(new Collection({
      type: "base",
      name: `${prefixe}memos`,
      listRule: acces,
      viewRule: acces,
      createRule: acces,
      updateRule: `${acces} && @request.body.t > t`,
      deleteRule: null,
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

  // Sert à vérifier le code d'équipe : la liste n'est visible qu'avec le bon code.
  const acc = new Collection({
    type: "base",
    name: "acces",
    listRule: acces,
    viewRule: acces,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [{ name: "nom", type: "text", max: 40 }],
  });
  app.save(acc);
  const enregistrement = new Record(acc);
  enregistrement.set("nom", "tournee-calendriers");
  app.save(enregistrement);
}, (app) => {
  for (const nom of ["statuts", "memos", "test_statuts", "test_memos", "acces"]) {
    app.delete(app.findCollectionByNameOrId(nom));
  }
});
