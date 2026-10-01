-- ============================================
-- MKR-SRC: SQL สำหรับ Supabase (ฉบับสมบูรณ์)
-- Run ใน SQL Editor ได้เลย (idempotent - run ซ้ำได้)
-- ============================================

-- 0. สร้างตาราง members (ถ้ายังไม่มี)
CREATE TABLE IF NOT EXISTS members (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  position TEXT DEFAULT '',
  emoji TEXT DEFAULT '🧑‍💻',
  email TEXT UNIQUE,
  phone TEXT DEFAULT '',
  password_hash TEXT DEFAULT '',
  rank TEXT DEFAULT 'employee',
  status TEXT DEFAULT 'active'
);
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all members" ON members;
CREATE POLICY "anon all members" ON members FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- 0.1 สร้างตาราง tasks (ถ้ายังไม่มี)
CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  who TEXT DEFAULT '',
  start_date TEXT DEFAULT '',
  due TEXT DEFAULT '',
  freq TEXT DEFAULT 'daily',
  emoji TEXT DEFAULT '🚗',
  status TEXT DEFAULT 'doing',
  checks JSONB DEFAULT '[]'::JSONB,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT DEFAULT ''
);
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all tasks" ON tasks;
CREATE POLICY "anon all tasks" ON tasks FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- 1. เพิ่มคอลัมน์ใหม่ในตาราง members (ถ้ายังไม่มี)
ALTER TABLE members ADD COLUMN IF NOT EXISTS email TEXT UNIQUE;
ALTER TABLE members ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE members ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE members ADD COLUMN IF NOT EXISTS rank TEXT DEFAULT 'employee';
ALTER TABLE members ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- 2. เพิ่มคอลัมน์ใหม่ในตาราง tasks (ถ้ายังไม่มี)
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS freq TEXT DEFAULT 'daily';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS start_date TEXT DEFAULT '';

-- 3. ตาราง requests (คำขออนุมัติ)
CREATE TABLE IF NOT EXISTS requests (
  id TEXT PRIMARY KEY,
  from_id TEXT, from_name TEXT, type TEXT,
  title TEXT, description TEXT, who TEXT, due TEXT, emoji TEXT,
  checks JSONB DEFAULT '[]'::JSONB, task_id TEXT,
  status TEXT DEFAULT 'pending', note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all requests" ON requests;
CREATE POLICY "anon all requests" ON requests FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- 4. ตาราง notifications (การแจ้งเตือน)
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  from_id TEXT, from_name TEXT, to_rank TEXT, to_id TEXT,
  type TEXT, title TEXT, message TEXT, link_id TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all notifications" ON notifications;
CREATE POLICY "anon all notifications" ON notifications FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- 5. ตาราง invites (การเชิญ)
CREATE TABLE IF NOT EXISTS invites (
  id TEXT PRIMARY KEY,
  email TEXT, rank TEXT DEFAULT 'employee',
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all invites" ON invites;
CREATE POLICY "anon all invites" ON invites FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- 6. ตาราง announcements (กระดานประกาศ)
CREATE TABLE IF NOT EXISTS announcements (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT DEFAULT '',
  author_name TEXT DEFAULT '',
  author_id TEXT DEFAULT '',
  is_pinned BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all announcements" ON announcements;
CREATE POLICY "anon all announcements" ON announcements FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- 7. ตาราง banned_emails (รายชื่อคนที่ถูกลบ ห้ามกลับมา)
CREATE TABLE IF NOT EXISTS banned_emails (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  banned_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE banned_emails ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all banned" ON banned_emails;
CREATE POLICY "anon all banned" ON banned_emails FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- 8. ตาราง events (ปฏิทินอีเวนต์ทีม Marketing)
CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  event_date TEXT DEFAULT '',
  time TEXT DEFAULT '',
  type TEXT DEFAULT 'event',
  description TEXT DEFAULT '',
  created_by TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all events" ON events;
CREATE POLICY "anon all events" ON events FOR ALL USING (TRUE) WITH CHECK (TRUE);

-- 9. คอลัมน์ acked_by ในตาราง announcements (รายชื่อคนที่รับทราบประกาศ)
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS acked_by JSONB DEFAULT '[]'::JSONB;

-- ============================================
-- 10. GRANT สิทธิ์ให้ role anon และ authenticated
-- (RLS policy ด้านบนอนุญาตแล้ว แต่ Postgres ต้องมี GRANT
--  ระดับตารางด้วย ไม่งั้นจะเจอ "permission denied for table ..."
--  แม้ policy จะเปิดกว้างแค่ไหนก็ตาม)
-- ============================================
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON
  members, tasks, requests, notifications, invites,
  announcements, banned_emails, events
  TO anon, authenticated;

-- 11. คอลัมน์ attachments ในตาราง tasks (ไฟล์แนบงาน — เก็บแค่ metadata/ลิงก์
--     ตัวไฟล์จริงเก็บบน Google Drive ไม่ได้เก็บในฐานข้อมูล)
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::JSONB;

-- ============================================
-- 12. (ตัดออกแล้ว) ฟังก์ชัน task_check_op มีอยู่ในฐานข้อมูลจริงแล้ว (สร้างไว้ก่อนหน้า ไม่เคย track ในไฟล์นี้)
--     ห้าม CREATE OR REPLACE / DROP ทับ — return type ไม่ตรงกับของเดิม จะ error หรือทำให้เชคลิสต์พัง
-- ============================================

-- ============================================
-- 13. เกมพักสมอง
--   game_scores = คะแนนเกมงูรายสัปดาห์ เก็บ 1 แถวต่อคนต่อสัปดาห์ (id = memberId_วันจันทร์)
--                 เก็บเฉพาะรอบที่คะแนนสูงสุด (เว็บอัปเดตเมื่อได้คะแนนมากกว่าเดิมเท่านั้น)
--   wheel_spins = ประวัติการหมุนวงล้อสุ่ม
-- ============================================
CREATE TABLE IF NOT EXISTS game_scores (
  id TEXT PRIMARY KEY,
  member_id TEXT NOT NULL,
  member_name TEXT DEFAULT '',
  week_start TEXT NOT NULL,
  score INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS game_scores_week ON game_scores(week_start);
ALTER TABLE game_scores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all game_scores" ON game_scores;
CREATE POLICY "anon all game_scores" ON game_scores FOR ALL USING (TRUE) WITH CHECK (TRUE);

CREATE TABLE IF NOT EXISTS wheel_spins (
  id TEXT PRIMARY KEY,
  by_id TEXT DEFAULT '',
  by_name TEXT DEFAULT '',
  result TEXT NOT NULL,
  topic TEXT DEFAULT '',
  mode TEXT DEFAULT 'team',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE wheel_spins ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all wheel_spins" ON wheel_spins;
CREATE POLICY "anon all wheel_spins" ON wheel_spins FOR ALL USING (TRUE) WITH CHECK (TRUE);

GRANT SELECT, INSERT, UPDATE, DELETE ON game_scores, wheel_spins TO anon, authenticated;

-- ============================================
-- 14. รูปโปรไฟล์ — เก็บรูปย่อ 160px (JPEG ~10KB) เป็นข้อความ data URL ในตาราง members
-- ============================================
ALTER TABLE members ADD COLUMN IF NOT EXISTS avatar TEXT DEFAULT '';

-- ✅ เสร็จสิ้น! ตารางครบแล้ว

-- ============================================
-- 15. บันทึกการเข้าระบบรายวัน (1 แถวต่อคนต่อวัน) — เว็บนับเฉพาะเดือนปัจจุบัน (รีเซ็ตทุกต้นเดือน)
-- ============================================
CREATE TABLE IF NOT EXISTS login_days (
  id TEXT PRIMARY KEY,
  member_id TEXT NOT NULL,
  day TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS login_days_day ON login_days(day);
ALTER TABLE login_days ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all login_days" ON login_days;
CREATE POLICY "anon all login_days" ON login_days FOR ALL USING (TRUE) WITH CHECK (TRUE);
GRANT SELECT, INSERT, UPDATE, DELETE ON login_days TO anon, authenticated;

-- ============================================
-- 16. ค่าตั้งระบบ (ปุ่มรีเซ็ตสถานะ) — key: login_reset / task_reset, value = วันที่เริ่มนับใหม่
-- ============================================
CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT DEFAULT '');
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon all app_settings" ON app_settings;
CREATE POLICY "anon all app_settings" ON app_settings FOR ALL USING (TRUE) WITH CHECK (TRUE);
GRANT SELECT, INSERT, UPDATE, DELETE ON app_settings TO anon, authenticated;
INSERT INTO app_settings (key, value) VALUES ('login_reset', to_char(now() AT TIME ZONE 'Asia/Bangkok','YYYY-MM-DD')), ('task_reset', to_char(now() AT TIME ZONE 'Asia/Bangkok','YYYY-MM-DD')) ON CONFLICT (key) DO NOTHING;

-- ============================================
-- 17. ผู้ร่วมงาน (มอบหมายงานได้หลายคน) — who = คนหลัก, co_who = รายชื่อ id ผู้ร่วมงาน
-- ============================================
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS co_who JSONB DEFAULT '[]'::JSONB;
