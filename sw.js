/* Service worker ของแอป MKT-SRC
   - หน้าเว็บ: ดึงของใหม่จากเน็ตก่อนเสมอ (network-first) → อัปเดตเว็บแล้วเห็นทันที ไม่ค้างเวอร์ชันเก่า
     ถ้าไม่มีเน็ต จึงเปิดสำเนาล่าสุดที่เก็บไว้
   - ไม่ยุ่งกับการเรียก Supabase / CDN (ข้อมูลสดเสมอ) */
const CACHE = "mkt-src-v2";   // v2: ล้างแคชเก่าที่สะสมจากตัวเช็คเวอร์ชัน
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
  const u = new URL(req.url);
  if (req.method !== "GET" || u.origin !== self.location.origin) return;
  if (u.search) return;   // URL มี ?… (เช่น ตัวเช็คเวอร์ชันใหม่) → ไม่เก็บลงแคช กันแคชบวมไม่จำกัด
  e.respondWith(
    fetch(req).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
      return res;
    }).catch(() => caches.match(req).then(r => r || caches.match("./")))
  );
});
