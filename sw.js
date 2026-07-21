/* Expiry Tracker — Service Worker (cache name tracks APP_VERSION; bump on every edit) */
const CACHE = 'expiry-tracker-v2.4';
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
  // Network-first for CDN resources (Tesseract), cache-first for local files
  const url = new URL(e.request.url);
  if (url.hostname === 'cdnjs.cloudflare.com') {
    e.respondWith(
      caches.open(CACHE).then(cache =>
        cache.match(e.request).then(cached => {
          if (cached) return cached;
          return fetch(e.request).then(res => {
            cache.put(e.request, res.clone());
            return res;
          });
        })
      )
    );
  } else {
    e.respondWith(
      caches.match(e.request).then(cached => cached || fetch(e.request))
    );
  }
});
