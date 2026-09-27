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
-- 12. ฟังก์ชัน task_check_op — จัดการเชคลิสต์ในงาน (ติ๊ก/เพิ่ม/ลบ/รีเซ็ตทั้งหมด)
-- ฝั่งเว็บเรียกผ่าน db.rpc("task_check_op", ...) ทุกครั้งที่แก้เชคลิสต์
-- (ทำผ่าน RPC ฝั่งเซิร์ฟเวอร์ กันติ๊กพร้อมกันหลายคนแล้วทับกัน)
-- CREATE OR REPLACE = รันซ้ำได้ปลอดภัย ถ้าฟังก์ชันนี้เคยมีปัญหา/หายไป รันสคริปต์นี้ใหม่จะซ่อมให้เอง
-- ============================================
CREATE OR REPLACE FUNCTION task_check_op(
  p_task TEXT,
  p_op TEXT,
  p_idx INT DEFAULT NULL,
  p_text TEXT DEFAULT NULL,
  p_on BOOLEAN DEFAULT NULL
) RETURNS tasks
LANGUAGE plpgsql
AS $$
DECLARE
  v_checks JSONB;
  v_row tasks;
  v_total INT;
  v_done INT;
BEGIN
  SELECT checks INTO v_checks FROM tasks WHERE id = p_task FOR UPDATE;
  IF v_checks IS NULL THEN v_checks := '[]'::JSONB; END IF;

  IF p_op = 'toggle' THEN
    v_checks := jsonb_set(v_checks, ARRAY[p_idx::text, 'on'], to_jsonb(COALESCE(p_on, false)));
  ELSIF p_op = 'add' THEN
    v_checks := v_checks || jsonb_build_array(jsonb_build_object('text', p_text, 'on', false));
  ELSIF p_op = 'del' THEN
    v_checks := v_checks - p_idx;
  ELSIF p_op = 'all' THEN
    SELECT COALESCE(jsonb_agg(jsonb_set(elem, ARRAY['on'], to_jsonb(COALESCE(p_on, false)))), '[]'::JSONB)
      INTO v_checks
      FROM jsonb_array_elements(v_checks) elem;
  END IF;

  v_total := jsonb_array_length(v_checks);
  SELECT COUNT(*) INTO v_done FROM jsonb_array_elements(v_checks) elem WHERE (elem->>'on')::boolean = true;

  UPDATE tasks SET
    checks = v_checks,
    status = CASE
      WHEN v_total > 0 AND v_done = v_total THEN 'done'
      WHEN status = 'done' THEN 'doing'
      ELSE status
    END,
    completed_at = CASE
      WHEN v_total > 0 AND v_done = v_total THEN COALESCE(completed_at, NOW())
      ELSE NULL
    END
  WHERE id = p_task
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;
GRANT EXECUTE ON FUNCTION task_check_op(TEXT, TEXT, INT, TEXT, BOOLEAN) TO anon, authenticated;

-- ✅ เสร็จสิ้น! ตารางครบแล้ว
