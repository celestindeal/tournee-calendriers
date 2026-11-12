# Tournée calendriers : serveur de synchronisation

Ce module permet à tous les téléphones de partager la tournée. Chaque téléphone envoie ses maisons au serveur et reçoit celles des autres. Pour une même maison, la modification la plus récente gagne.

Sur les téléphones, il n'y a rien à régler : l'adresse du serveur et la clé de synchronisation sont intégrées à l'app quand GitHub la construit (variable `SYNCHRO_ADRESSE` et secret `SYNCHRO_CLE` du dépôt).

## Mise en route

1. Dans l'onglet **Configuration**, saisissez la **clé de synchronisation**. Ce doit être la même que le secret `SYNCHRO_CLE` du dépôt GitHub. Enregistrez.
2. Démarrez le module, puis ouvrez l'onglet **Journal**.
3. Au premier démarrage, un lien `https://login.tailscale.com/…` s'affiche. Ouvrez-le et connectez-vous à Tailscale : un compte gratuit suffit, avec Google, Microsoft ou GitHub.
4. Si un deuxième lien s'affiche pour **Funnel**, ouvrez-le et acceptez. Funnel rend le serveur joignable depuis Internet, en HTTPS.
   Ensuite, **redémarrez le module** : sans cela, Tailscale ne fournit pas le certificat HTTPS et l'adresse ne répond pas.
5. Le journal affiche ensuite l'adresse du serveur, par exemple `https://serveur-pompier.tail1234.ts.net`. Enregistrez-la dans la variable `SYNCHRO_ADRESSE` du dépôt GitHub.

## Bon à savoir

- **Données** : seulement l'identifiant cadastral de chaque maison, son statut, ses mémos et leur date. Elles restent sur cette machine et sont incluses dans les **sauvegardes de Home Assistant**.
- **Sécurité** : sans la clé, le serveur ne montre et n'accepte rien. Personne ne peut rien supprimer depuis un téléphone. Seul le site de l'app (celestindeal.github.io) peut l'appeler depuis un navigateur. Comme la clé est dans l'app, elle arrête les robots et les curieux, mais pas quelqu'un de déterminé qui lirait le code de l'app.
- **Changer la clé** : modifiez-la ici et dans le secret GitHub, puis redémarrez le module et republiez l'app.
- **Si le module est arrêté**, l'app continue de fonctionner sans réseau. Chaque téléphone envoie ses changements quand le serveur revient.
- L'environnement de **test** de l'app utilise des tables séparées (`test_…`) : ses essais ne se mélangent jamais avec la vraie tournée.
