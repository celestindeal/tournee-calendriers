# Reprendre le projet

Point d'arrêt : **13 novembre 2026**. Le MVP est validé et en production : c'est la version marquée `v1.0-mvp` dans Git. On reprendra après les premiers retours de la caserne.

## Où en est-on

| Quoi | Où |
| --- | --- |
| App de la tournée (production) | https://celestindeal.github.io/tournee-calendriers/ (branche `main`) |
| App d'essai (TEST) | https://celestindeal.github.io/tournee-calendriers/test/ (branche `test`) |
| Serveur de synchronisation | https://serveur-pompier.tail8a91ff.ts.net : module « Tournée calendriers » 1.0.3 dans Home Assistant, sur la Raspberry Pi 5 (Wi-Fi) |
| Mode d'emploi à imprimer | [docs/guide/Guide_Tournee_Calendriers.pdf](guide/Guide_Tournee_Calendriers.pdf) |
| Code source | https://github.com/celestindeal/tournee-calendriers |

**Ce que fait l'app :**
- carte des 6 communes (5 776 maisons, par parcelle cadastrale), couleur par statut, compteur ;
- hors ligne ;
- synchronisation entre téléphones, sans rien à régler ;
- 11 tournées : « Ma tournée » et « Afficher toutes les tournées » ;
- mémos, listes, recherche d'adresse, itinéraire ;
- campagnes par année : les « non concerné » et les mémos sont gardés ;
- export et import ;
- iPhone et Android.

**Différence entre les branches :** `test` a un commit de plus que `main`, le mode d'emploi (documentation seulement). On l'enverra en production avec la prochaine modification.

## Se remettre au travail

1. Ouvrir le dossier `G:\Mon Drive\Appli Tournée Calendriers Pompiers`. Vérifier qu'on est sur la branche **`test`** et que `git status` ne montre rien d'inattendu.
2. Flutter et `gh` ne sont pas dans le PATH :
   - Flutter : `C:\flutter\flutter\bin\flutter.bat`
   - Dart : `C:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe`
   - gh : `C:\Program Files\GitHub CLI\gh.exe`
3. Lancer les tests (140 au point d'arrêt) : `flutter test`. Pour l'analyse, utiliser `dart analyze` : `flutter analyze` plante à cause du « é » du chemin.
4. Le cycle de travail :
   1. on modifie sur `test` ;
   2. on pousse ;
   3. on essaie sur le téléphone avec l'app TEST ;
   4. une fois validé, on met en production avec `git push origin test:main`.

   Le détail est dans le [README](../README.md).
5. **Google Drive** peut remettre d'anciennes versions des fichiers non commités : commiter souvent.

## Le serveur (Raspberry Pi)

- Dans Home Assistant (`http://homeassistant.local:8123`), ouvrir **Paramètres → Apps → Tournée calendriers**. Le chien de garde est activé, et les données sont dans les sauvegardes de Home Assistant.
- **Après un redémarrage de la Pi**, compter 7 à 8 minutes avant que l'adresse réponde. Le journal du module affiche « Certificat HTTPS prêt » puis « Serveur prêt ».
- **Pour mettre à jour le module** :
  1. augmenter `version` dans `serveur/config.yaml` ;
  2. pousser `test` ;
  3. dans Home Assistant, Boutique → ⋮ → « Rechercher des mises à jour » ;
  4. ouvrir le module, puis « Mettre à jour ».
- **Clé de synchronisation** : elle est dans l'option du module et dans le secret GitHub `SYNCHRO_CLE`. Gardez-en une copie en lieu sûr (gestionnaire de mots de passe) : elle ne doit **jamais** être écrite dans ce dépôt public. L'adresse est dans la variable GitHub `SYNCHRO_ADRESSE`. Changer la clé = la changer aux deux endroits, puis republier l'app.
- La notice complète se trouve dans [serveur/LISEZMOI.md](../serveur/LISEZMOI.md) et [serveur/DOCS.md](../serveur/DOCS.md).

## À faire / à surveiller

- [ ] Essayer l'app sur un **vrai téléphone Android** : bouton « Installer », itinéraire, bouton retour.
- [ ] Mode d'emploi : remplacer les étapes d'installation **dessinées** (Safari, Chrome) par de vraies captures de téléphone. Ensuite, lancer `dart run tool/guide_pdf.dart`.
- [ ] Deux maisons du chemin de Montgiraud (203, 305/307) sont dans les contours des tournées **7 et 10**. Elles sont comptées en 7. Ajuster le contour dans Google My Maps si besoin ([tuto](AJOUTER_UNE_TOURNEE.md)).
- [ ] Avant la prochaine tournée (novembre 2027) :
  1. **exporter** la campagne 2026 (Menu → Exporter) ;
  2. **faire une sauvegarde de Home Assistant** ;
  3. Menu → **Nouvelle campagne…** sur un téléphone.
- [ ] Recueillir les retours de la caserne.

## Idées gardées pour plus tard

- Bouton **Annuler** le dernier changement (F10 du cahier des charges).
- Date du passage affichée dans le panneau d'une maison.
- Rappel d'export régulier.
- Statistiques par tournée et par commune.
- Montant des dons (attention au RGPD).

## Bon à savoir

- **Quatre `git stash`** contiennent des restes de Google Drive sans valeur : on peut les supprimer avec `git stash clear`.
- Les **contours des tournées** viennent des fichiers KML « Tournée n°X.kml » : il faut tous les repasser ensemble au script (voir le [tuto](AJOUTER_UNE_TOURNEE.md)).
- Les **données du cadastre** se regénèrent avec `tool/preparer_donnees.dart`, de préférence entre deux campagnes.
