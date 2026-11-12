# Tournée calendriers : serveur de synchronisation

Ce module permet à plusieurs téléphones de partager la tournée. Chaque téléphone envoie ses maisons au serveur et reçoit celles des autres. Pour une même maison, la modification la plus récente gagne.

## Mise en route

1. Dans l'onglet **Configuration**, choisissez un **code d'équipe** : 12 caractères minimum (lettres, chiffres, tirets), par exemple `sapin-falaise-4821-brume`. Enregistrez.
2. Démarrez le module, puis ouvrez l'onglet **Journal**.
3. Au premier démarrage, un lien `https://login.tailscale.com/…` s'affiche. Ouvrez-le et connectez-vous à Tailscale : un compte gratuit suffit, avec Google, Microsoft ou GitHub.
4. Si un deuxième lien s'affiche pour **Funnel**, ouvrez-le aussi et acceptez. Funnel rend le serveur joignable depuis Internet, en HTTPS.
5. Le journal affiche ensuite l'adresse à saisir dans l'app, par exemple : `https://serveur-pompier.tail1234.ts.net`

Dans l'app, sur chaque téléphone, allez dans **Menu → Synchronisation**, puis saisissez l'adresse et le code d'équipe.

## Bon à savoir

- **Données** : seulement l'identifiant cadastral de chaque maison, son statut, ses mémos et leur date. Elles restent sur cette machine et sont incluses dans les **sauvegardes de Home Assistant**.
- **Sécurité** : sans le code d'équipe, le serveur ne montre et n'accepte rien. Personne ne peut rien supprimer depuis un téléphone. Seul le site de l'app (celestindeal.github.io) peut l'appeler depuis un navigateur.
- **Changer le code** : modifiez-le dans la configuration et redémarrez le module. Il faut ensuite le resaisir sur chaque téléphone.
- **Si le module est arrêté**, l'app continue de fonctionner sans réseau. Chaque téléphone envoie ses changements quand le serveur revient.
- L'environnement de **test** de l'app utilise des tables séparées (`test_…`) : ses essais ne se mélangent jamais avec la vraie tournée.
