# Serveur de synchronisation

Ce serveur permet à plusieurs téléphones de partager la tournée. Ce dossier est un **module Home Assistant** (une « App ») ; il tourne sur la Raspberry Pi 5 qui fait déjà tourner Home Assistant.

| Fichier | Rôle |
| --- | --- |
| `config.yaml`, `Dockerfile`, `run.sh` | Le module : il installe PocketBase (avec vérification de l'empreinte) et Tailscale, puis les démarre. |
| `pb_hooks/tournee.pb.js` | Crée les tables et applique la clé de synchronisation à chaque démarrage. Les modifications ne sont acceptées que si elles sont plus récentes, et les suppressions sont interdites. |
| `DOCS.md`, `translations/fr.yaml` | La documentation et les libellés affichés dans Home Assistant. |
| `../repository.yaml` | Fait du dépôt GitHub un dépôt de modules Home Assistant. |

## Installer dans Home Assistant

1. Ouvrir **Paramètres → Apps → Boutique**, puis le menu **⋮ → Dépôts**.
2. Ajouter l'adresse `https://github.com/celestindeal/tournee-calendriers#test` : `#test` désigne la branche `test`.
3. Installer **Tournée calendriers**. L'installation prend quelques minutes, car le module est construit sur la Pi.
4. Suivre l'onglet **Documentation** du module : régler la clé de synchronisation, démarrer, ouvrir le lien Tailscale affiché dans le journal, puis noter l'adresse publique.

Pour publier une nouvelle version du module : augmenter `version` dans `config.yaml`, pousser la branche `test`, puis cliquer sur « Mettre à jour » dans Home Assistant.

## Essayer en local, sur le PC

```bash
CLE_SYNCHRO=essai-local-123456 pocketbase serve --http=127.0.0.1:8090 --dir=pb_data --hooksDir=serveur/pb_hooks --origins=http://localhost:8080
```

```bash
flutter test test/synchro/serveur_reel_test.dart --dart-define=POCKETBASE=http://127.0.0.1:8090 --dart-define=CLE=essai-local-123456
```
