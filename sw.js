/* Expiry Tracker — Service Worker (cache name tracks APP_VERSION; bump on every edit) */
const CACHE = 'expiry-tracker-v2.5';
const ASSETS = [
  './',
  './index.html',
  './manifest.json',
  'https://cdnjs.cloudflare.com/ajax/libs/tesseract.js/5.0.4/tesseract.min.js'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(cache => {
      // Cache core files; Tesseract CDN may fail offline — that's OK
      return cache.addAll(['./index.html', './manifest.json']).catch(() => {});
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const req = e.request, url = new URL(req.url);

  // Only ever manage GET. Let POST/PUT/etc (e.g. the Google Vision API call)
  // pass straight through to the network — intercepting them caused
  // "FetchEvent.respondWith received an error: Load failed".
  if (req.method !== 'GET') return;

  // Tesseract CDN: cache-first, fall back to network; never reject respondWith.
  if (url.hostname === 'cdnjs.cloudflare.com') {
    e.respondWith(
      caches.open(CACHE).then(cache =>
        cache.match(req).then(cached =>
          cached || fetch(req).then(res => { cache.put(req, res.clone()); return res; })
        )
      ).catch(() => fetch(req).catch(() => new Response('', { status: 504 })))
    );
    return;
  }

  // Only handle same-origin assets; other cross-origin GETs go to network untouched.
  if (url.origin !== self.location.origin) return;

  e.respondWith(
    caches.match(req).then(cached =>
      cached || fetch(req).catch(() => cached || new Response('', { status: 504 }))
    )
  );
});
