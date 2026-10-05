/* Service worker ของแอป MKT-SRC
   - หน้าเว็บ: ดึงของใหม่จากเน็ตก่อนเสมอ (network-first) → อัปเดตเว็บแล้วเห็นทันที ไม่ค้างเวอร์ชันเก่า
     ถ้าไม่มีเน็ต จึงเปิดสำเนาล่าสุดที่เก็บไว้
   - ไม่ยุ่งกับการเรียก Supabase / CDN (ข้อมูลสดเสมอ) */
const CACHE = "mkt-src-v1";
const SHELL = ["./", "assets/logo-256.png", "assets/icon-192.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).catch(() => {}));
  self.skipWaiting();
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET" || new URL(req.url).origin !== self.location.origin) return;
  e.respondWith(
    fetch(req).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
      return res;
    }).catch(() => caches.match(req).then(r => r || caches.match("./")))
  );
});
