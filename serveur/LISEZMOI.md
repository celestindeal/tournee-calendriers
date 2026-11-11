# Serveur de synchronisation (Raspberry Pi)

Le serveur permet à plusieurs téléphones de partager la tournée. Il tourne sur une Raspberry Pi 5 branchée sur la box, chez un membre de l'équipe.

- **PocketBase** : un petit serveur gratuit en un seul fichier. Il garde les statuts et les mémos dans une base SQLite.
- **Tailscale Funnel** : il donne à la Pi une adresse publique en HTTPS (`https://serveur-pompier.xxxx.ts.net`), avec un certificat valide. Il n'y a aucun port à ouvrir sur la box et aucun nom de domaine à acheter.
- **`pb_migrations/1794400000_tournee.js`** : ce script crée les tables au premier démarrage. Le code d'équipe n'est pas dans ce dépôt public : il est lu dans la variable `CODE_EQUIPE`.

L'app fonctionne même si la Pi est éteinte : chaque téléphone garde ses changements et les envoie quand le serveur répond de nouveau.

## 1. Préparer la clé USB (sur le PC)

1. Installer Raspberry Pi Imager, sur raspberrypi.com/software.
2. Faire les choix suivants dans Imager :
   - Appareil : **Raspberry Pi 5** ;
   - Système : *Raspberry Pi OS (other)* → **Raspberry Pi OS Lite (64-bit)** ;
   - Stockage : la clé USB, qui sera **effacée**.
3. Dans les réglages, choisir :
   - le nom d'hôte **`serveur-pompier`** ;
   - un utilisateur et son mot de passe ;
   - le fuseau Europe/Paris et le clavier fr ;
   - **SSH activé** (onglet Services).
4. Brancher la clé sur un port USB bleu de la Pi, sans carte SD. Brancher aussi le câble Ethernet relié à la box, puis l'alimentation.

La Pi est prête quand `ping serveur-pompier.local` répond depuis le PC, puis quand `ssh utilisateur@serveur-pompier.local` ouvre une session.

Si la Pi refuse de démarrer sur la clé avec un chargeur qui n'est pas le bloc officiel 27 W, ajouter `usb_max_current_enable=1` dans `/boot/firmware/config.txt`. Il faut alors brancher la clé sur un PC pour modifier ce fichier.

## 2. Installer PocketBase (dans la session SSH)

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y unzip
sudo useradd --system --home /opt/pocketbase --create-home pocketbase
```

1. Télécharger la dernière version `linux_arm64` depuis les « releases » GitHub de `pocketbase/pocketbase`, puis la décompresser dans `/opt/pocketbase`.
2. Copier le dossier `pb_migrations` de ce dépôt dans `/opt/pocketbase/pb_migrations`.

Le service ci-dessous, à placer dans `/etc/systemd/system/pocketbase.service`, démarre PocketBase avec la Pi :

```ini
[Unit]
Description=PocketBase (tournée calendriers)
After=network.target

[Service]
User=pocketbase
WorkingDirectory=/opt/pocketbase
Environment=CODE_EQUIPE=le-code-d-equipe
ExecStart=/opt/pocketbase/pocketbase serve --http=127.0.0.1:8090 --origins=https://celestindeal.github.io
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pocketbase
```

Le code d'équipe doit être long : 12 caractères au minimum, uniquement des lettres, des chiffres et des tirets. Par exemple : `sapin-falaise-4821-brume`.

## 3. Ouvrir l'adresse HTTPS (Tailscale Funnel)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
sudo tailscale funnel --bg 8090
```

1. `tailscale up` affiche un lien. L'ouvrir pour se connecter au compte Tailscale gratuit.
2. `tailscale funnel` affiche l'adresse publique. C'est l'adresse à saisir dans l'app, dans Menu → Synchronisation.

## 4. Sauvegardes

La base se trouve dans `/opt/pocketbase/pb_data`. PocketBase peut faire une sauvegarde automatique chaque nuit : la régler dans son interface d'administration (Settings → Backups). Copier aussi régulièrement ces sauvegardes ailleurs, car une clé USB peut lâcher.
