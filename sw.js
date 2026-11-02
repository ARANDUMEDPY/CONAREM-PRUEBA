// Service worker de AranduMed: guarda la app para abrir rápido y sin conexión.
// Las preguntas se guardan aparte (IndexedDB); los datos de Supabase nunca se cachean acá.
const CACHE = 'arandumed-v1';
const SHELL = ['./', 'index.html', 'config.js', 'manifest.webmanifest', 'icons/icon-192.png', 'icons/icon-512.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.hostname.endsWith('supabase.co')) return;
  const isPage = e.request.mode === 'navigate' || u.pathname.endsWith('.html') || u.pathname.endsWith('config.js');
  if (isPage) {
    // Primero la red (para recibir actualizaciones); si no hay conexión, la copia guardada.
    e.respondWith(fetch(e.request).then(r => { const c = r.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); return r; }).catch(() => caches.match(e.request).then(r => r || caches.match('index.html'))));
  } else if (u.origin === location.origin || u.hostname.includes('jsdelivr') || u.hostname.includes('fonts.g')) {
    // Íconos, librerías y fuentes: primero la copia guardada.
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request).then(res => { const c = res.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); return res; })));
  }
});
