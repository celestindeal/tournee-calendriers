#!/bin/sh
# Démarrage du module : PocketBase (données dans /data, sauvegardé par Home
# Assistant), puis Tailscale Funnel pour l'adresse HTTPS publique.
set -eu

OPTIONS=/data/options.json
CODE=$(jq -r '.code_equipe // ""' "$OPTIONS")
NOM=$(jq -r '.nom_tailscale // "serveur-pompier"' "$OPTIONS")
CLE=$(jq -r '.cle_tailscale // ""' "$OPTIONS")

if ! echo "$CODE" | grep -Eq '^[A-Za-z0-9-]{12,}$'; then
  echo "[tournée] ERREUR : réglez un code d'équipe (onglet Configuration) :"
  echo "[tournée] 12 caractères minimum, lettres, chiffres et tirets."
  exit 1
fi

mkdir -p /data/pb_data /data/tailscale /var/run/tailscale
SOCKET=/var/run/tailscale/tailscaled.sock
TS="tailscale --socket=$SOCKET"

echo "[tournée] Démarrage du serveur PocketBase…"
CODE_EQUIPE="$CODE" /opt/pocketbase/pocketbase serve \
  --http=127.0.0.1:8090 \
  --dir=/data/pb_data \
  --hooksDir=/opt/pocketbase/pb_hooks \
  --origins=https://celestindeal.github.io &
PB=$!

echo "[tournée] Démarrage de Tailscale…"
tailscaled --tun=userspace-networking --statedir=/data/tailscale --socket="$SOCKET" >/dev/null 2>&1 &
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

echo "[tournée] Ouverture de l'adresse publique (Tailscale Funnel). Si un lien s'affiche,"
echo "[tournée] ouvrez-le pour autoriser Funnel, le module continue tout seul ensuite."
$TS funnel --bg 8090

ADRESSE=$($TS status --json | jq -r '.Self.DNSName' | sed 's/\.$//')
echo "[tournée] ------------------------------------------------------------"
echo "[tournée] Serveur prêt. Adresse à saisir dans l'app (Menu → Synchronisation) :"
echo "[tournée]   https://$ADRESSE"
echo "[tournée] ------------------------------------------------------------"

# Le module s'arrête si PocketBase s'arrête (Home Assistant l'affiche).
wait "$PB"
