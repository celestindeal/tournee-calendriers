// Service worker de l'appli tournée calendriers (ARCHITECTURE §7.1).
//
// ⚠️ Modèle : tool/generer_sw.dart y insère la version et la liste des
// fichiers, et écrit le résultat dans build/web/sw.js après chaque build.
//
// - install  : met en cache toute l'app (pré-cache).
// - fetch    : app servie depuis le cache d'abord (démarrage sans réseau) ;
//              tuiles OSM déjà vues gardées dans un cache séparé et plafonné.
// - activate : supprime les caches des versions précédentes.
// Ne touche jamais à IndexedDB : une mise à jour n'efface pas les statuts.

'use strict';

const VERSION = '__VERSION__';
const CACHE_APP = 'app-' + VERSION;
const CACHE_TUILES = 'tuiles-osm-v1';
const MAX_TUILES = 1500;

/** Fichiers de l'app, relatifs au service worker. */
const FICHIERS = __FICHIERS__;

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_APP);
    // « no-cache » : le navigateur vérifie auprès du serveur que chaque fichier
    // est à jour, sans le retélécharger s'il l'a déjà (premier affichage).
    await cache.addAll(FICHIERS.map((f) => new Request(f, { cache: 'no-cache' })));
    // La nouvelle version prend la main tout de suite ; l'écran déjà ouvert
    // continue avec l'ancienne, la suivante s'ouvrira sur la nouvelle.
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const nom of await caches.keys()) {
      if (nom.startsWith('app-') && nom !== CACHE_APP) await caches.delete(nom);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const requete = event.request;
  if (requete.method !== 'GET') return;
  const url = new URL(requete.url);

  if (url.hostname === 'tile.openstreetmap.org') {
    event.respondWith(tuile(requete));
  } else if (url.origin === self.location.origin) {
    event.respondWith(fichierApp(requete));
  }
  // Autres domaines : comportement normal du navigateur.
});

/** App : cache d'abord, réseau sinon (et on garde la réponse pour la suite). */
async function fichierApp(requete) {
  const cache = await caches.open(CACHE_APP);
  const enCache = await cache.match(requete, { ignoreSearch: true });
  if (enCache) return enCache;

  // Ouverture de l'app (« navigation ») : toujours la page d'accueil en cache.
  if (requete.mode === 'navigate') {
    const accueil = await cache.match('./') || await cache.match('index.html');
    if (accueil) return accueil;
  }

  const reponse = await fetch(requete);
  if (reponse.ok) cache.put(requete, reponse.clone());
  return reponse;
}

/** Tuiles OSM : cache d'abord ; seules les tuiles vues sont gardées (politique OSM). */
async function tuile(requete) {
  const cache = await caches.open(CACHE_TUILES);
  const enCache = await cache.match(requete);
  if (enCache) return enCache;

  const reponse = await fetch(requete);
  if (reponse.ok) {
    await cache.put(requete, reponse.clone());
    limiterTuiles(cache);
  }
  return reponse;
}

/** Supprime les tuiles les plus anciennes au-delà de MAX_TUILES. */
async function limiterTuiles(cache) {
  const cles = await cache.keys();
  for (let i = 0; i < cles.length - MAX_TUILES; i++) {
    await cache.delete(cles[i]);
  }
}
