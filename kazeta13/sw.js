const CACHE='kazeta13-v2';
const CORE=['./','./index.html','./hra.html','./three.min.js','./manifest.webmanifest','./icon.svg','./icon-180.png','./icon-192.png','./icon-512.png'];
const EXTRA=['https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE).then(()=>Promise.all(EXTRA.map(u=>c.add(u).catch(()=>{}))))).then(()=>self.skipWaiting()));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(n=>n!==CACHE).map(n=>caches.delete(n)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;
 e.respondWith(caches.match(e.request).then(hit=>{const net=fetch(e.request).then(r=>{if(r&&(r.ok||r.type==='opaque')){const cp=r.clone();caches.open(CACHE).then(c=>c.put(e.request,cp));}return r;}).catch(()=>hit);return hit||net;}));});
