-- Supabase Notlar ve Alarmlar Tabloları
-- Bu SQL'i Supabase SQL Editor'de çalıştırın.

-- ========== 1. Notlar Tablosu ==========
CREATE TABLE IF NOT EXISTS stock_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  symbol TEXT NOT NULL,
  note TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ========== 2. Alarmlar Tablosu ==========
CREATE TABLE IF NOT EXISTS stock_alarms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  symbol TEXT NOT NULL,
  alarm_type TEXT NOT NULL CHECK (alarm_type IN ('target', 'stop')),
  target_price NUMERIC(15, 4) NOT NULL CHECK (target_price > 0),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_triggered BOOLEAN NOT NULL DEFAULT false,
  triggered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, symbol, alarm_type)
);

-- ========== 3. RLS Politikaları - Notlar ==========
ALTER TABLE stock_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stock_notes_select_own" ON stock_notes;
CREATE POLICY "stock_notes_select_own" ON stock_notes
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "stock_notes_insert_own" ON stock_notes;
CREATE POLICY "stock_notes_insert_own" ON stock_notes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "stock_notes_update_own" ON stock_notes;
CREATE POLICY "stock_notes_update_own" ON stock_notes
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "stock_notes_delete_own" ON stock_notes;
CREATE POLICY "stock_notes_delete_own" ON stock_notes
  FOR DELETE USING (auth.uid() = user_id);

-- ========== 4. RLS Politikaları - Alarmlar ==========
ALTER TABLE stock_alarms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stock_alarms_select_own" ON stock_alarms;
CREATE POLICY "stock_alarms_select_own" ON stock_alarms
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "stock_alarms_insert_own" ON stock_alarms;
CREATE POLICY "stock_alarms_insert_own" ON stock_alarms
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "stock_alarms_update_own" ON stock_alarms;
CREATE POLICY "stock_alarms_update_own" ON stock_alarms
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "stock_alarms_delete_own" ON stock_alarms;
CREATE POLICY "stock_alarms_delete_own" ON stock_alarms
  FOR DELETE USING (auth.uid() = user_id);

-- ========== 5. Index'ler (Performans için) ==========
CREATE INDEX IF NOT EXISTS idx_stock_notes_user_symbol ON stock_notes(user_id, symbol);
CREATE INDEX IF NOT EXISTS idx_stock_notes_created_at ON stock_notes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_alarms_user_symbol ON stock_alarms(user_id, symbol);
CREATE INDEX IF NOT EXISTS idx_stock_alarms_active ON stock_alarms(is_active, is_triggered) WHERE is_active = true AND is_triggered = false;
