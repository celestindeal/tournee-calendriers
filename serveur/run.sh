#!/bin/sh
# Démarrage du module : PocketBase (données dans /data, sauvegardé par Home
# Assistant), puis Tailscale Funnel pour l'adresse HTTPS publique.
set -eu

OPTIONS=/data/options.json
CLE_SYNCHRO_OPTION=$(jq -r '.cle_synchro // ""' "$OPTIONS")
NOM=$(jq -r '.nom_tailscale // "serveur-pompier"' "$OPTIONS")
CLE=$(jq -r '.cle_tailscale // ""' "$OPTIONS")

if ! echo "$CLE_SYNCHRO_OPTION" | grep -Eq '^[A-Za-z0-9-]{12,}$'; then
  echo "[tournée] ERREUR : réglez une clé de synchronisation (onglet Configuration) :"
  echo "[tournée] 12 caractères minimum, lettres, chiffres et tirets."
  exit 1
fi

mkdir -p /data/pb_data /data/tailscale /data/tailscale/certificat /var/run/tailscale
SOCKET=/var/run/tailscale/tailscaled.sock
TS="tailscale --socket=$SOCKET"

echo "[tournée] Démarrage du serveur PocketBase…"
CLE_SYNCHRO="$CLE_SYNCHRO_OPTION" /opt/pocketbase/pocketbase serve \
  --http=127.0.0.1:8090 \
  --dir=/data/pb_data \
  --hooksDir=/opt/pocketbase/pb_hooks \
  --origins=https://celestindeal.github.io &
PB=$!

echo "[tournée] Démarrage de Tailscale…"
# Journal de Tailscale : seules les lignes utiles (connexion, certificat
# HTTPS, Funnel, erreurs) sont recopiées dans le journal du module.
tailscaled --tun=userspace-networking --statedir=/data/tailscale --socket="$SOCKET" 2>&1 \
  | grep --line-buffered -iE "cert|acme|funnel|serve|tls|error|fail|denied|derp.*(home|connected)|LinkChange" \
  | sed -u 's/^/[tailscale] /' &
for _ in $(seq 1 30); do
  [ -S "$SOCKET" ] && break
  sleep 1
done

echo "[tournée] Connexion à Tailscale. Si un lien https://login.tailscale.com/… s'affiche"
echo "[tournée] ci-dessous, ouvrez-le pour relier ce serveur à votre compte Tailscale."
if [ -n "$CLE" ]; then
  $TS up --hostname="$NOM" --authkey="$CLE"
else
  $TS up --hostname="$NOM"
fi

# Au démarrage de la Raspberry Pi, le réseau (Wi-Fi) et l'heure peuvent ne pas
# être prêts : on attend que Tailscale soit vraiment connecté.
etat() { $TS status --json 2>/dev/null | jq -r '.BackendState // "?"'; }
for i in $(seq 1 60); do
  [ "$(etat)" = "Running" ] && break
  [ "$i" = 1 ] && echo "[tournée] En attente de la connexion à Tailscale…"
  sleep 5
done
echo "[tournée] Tailscale : $(etat), heure : $(date -u '+%Y-%m-%d %H:%M:%S') UTC"

ADRESSE=$($TS status --json | jq -r '.Self.DNSName' | sed 's/\.$//')

# Certificat HTTPS de l'adresse publique : demandé explicitement, et redemandé
# tant qu'il n'est pas obtenu (sinon Funnel répond sans certificat et l'app
# ne peut pas joindre le serveur).
for i in $(seq 1 40); do
  if sortie=$($TS cert --cert-file /data/tailscale/certificat/cert.pem --key-file /data/tailscale/certificat/cle.pem "$ADRESSE" 2>&1); then
    echo "[tournée] Certificat HTTPS prêt pour $ADRESSE."
    break
  fi
  echo "[tournée] Certificat HTTPS pas encore obtenu (essai $i) : $sortie"
  sleep 30
done

echo "[tournée] Ouverture de l'adresse publique (Tailscale Funnel). Si un lien s'affiche,"
echo "[tournée] ouvrez-le pour autoriser Funnel, le module continue tout seul ensuite."
$TS funnel --bg 8090
$TS funnel status 2>&1 | sed 's/^/[tailscale] /'

echo "[tournée] ------------------------------------------------------------"
echo "[tournée] Serveur prêt. Adresse publique : https://$ADRESSE"
echo "[tournée] ------------------------------------------------------------"

# Le module s'arrête si PocketBase s'arrête (Home Assistant l'affiche, et le
# chien de garde le relance).
wait "$PB"
