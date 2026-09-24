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

-- ✅ เสร็จสิ้น! ตารางครบแล้ว
