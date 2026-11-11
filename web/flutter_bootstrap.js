{{flutter_js}}
{{flutter_build_config}}

// Démarrage personnalisé (ARCHITECTURE §7.1).
//
// On ne passe PAS de « serviceWorkerSettings » : ainsi Flutter n'enregistre
// pas son propre service worker, déprécié, qui ne met rien en cache et se
// désinscrit tout seul (il remplacerait le nôtre).
//
// Notre service worker (sw.js, généré par tool/generer_sw.dart) est enregistré
// une fois l'app affichée, pour ne pas ralentir le premier chargement en 4G.
_flutter.loader.load({
  config: {
    // Variante complète du moteur de rendu dans TOUS les navigateurs : c'est
    // celle que Safari utilise de toute façon, la seule mise en cache par sw.js.
    // Chrome se comporte ainsi comme l'iPhone (hors-ligne testable sur le PC).
    canvasKitVariant: 'full',
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.getElementById('chargement')?.remove();

    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('sw.js').catch(function (erreur) {
        // Normal en mode debug (pas de sw.js) : l'app marche, sans hors-ligne.
        console.warn('Service worker non enregistré :', erreur);
      });
    }
  },
});
