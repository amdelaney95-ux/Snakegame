// Run after Godot's Web export. No external packages are required.
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const dir = path.resolve(process.argv[2] || path.join(__dirname, '../.build/web'));
const manifestPath = path.join(dir, 'index.manifest.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
Object.assign(manifest, {id:'./', name:'Snake Stages', short_name:'Snake Stages', start_url:'./', scope:'./', display:'standalone', orientation:'any', background_color:'#101b24', theme_color:'#101b24', description:'Campaign, Endless, and Adventure. A Snake game for keyboard and touch.'});
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
fs.writeFileSync(path.join(dir, '.nojekyll'), '');
const files = fs.readdirSync(dir).filter(f => !f.startsWith('.') && !f.endsWith('.service.worker.js') && !f.endsWith('.md'));
const hash = crypto.createHash('sha256');
for (const file of files.sort()) hash.update(file).update(fs.readFileSync(path.join(dir, file)));
const version = hash.digest('hex').slice(0, 16);
fs.writeFileSync(path.join(dir,'index.service.worker.js'), `/* Snake Stages: atomic offline bundles; upgrades wait for the player's choice. */
const VERSION = ${JSON.stringify(version)};
const PREFIX = 'snake-stages:' + self.registration.scope + ':';
const CACHE = PREFIX + VERSION;
const FILES = ${JSON.stringify(files)};
const urls = FILES.map(file => new URL(file, self.registration.scope).href);
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(urls.map(url => new Request(url, {cache:'reload'}))))));
self.addEventListener('activate', event => event.waitUntil((async()=>{for(const key of await caches.keys())if(key.startsWith(PREFIX)&&key!==CACHE)await caches.delete(key);await self.clients.claim()})()));
self.addEventListener('message', event => {if(event.data?.type==='SKIP_WAITING')self.skipWaiting()});
self.addEventListener('fetch', event => {
  if(event.request.method!=='GET')return;
  const url = new URL(event.request.url);
  if(url.origin!==self.location.origin || !url.href.startsWith(self.registration.scope))return;
  let key=url.href;
  if(event.request.mode==='navigate' && (url.pathname===new URL(self.registration.scope).pathname || url.pathname.endsWith('/index.html'))) key=new URL('index.html',self.registration.scope).href;
  if(!urls.includes(key))return;
  event.respondWith((async()=>{const cache=await caches.open(CACHE);return await cache.match(key) || fetch(event.request)})());
});
`);
console.log(`Web build ${version}: ${files.length} cached files; single-threaded PWA ready.`);
