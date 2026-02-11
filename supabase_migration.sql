-- Supabase Portfolio ve Transactions Tabloları - User Bazlı Migration
-- Bu SQL'i Supabase SQL Editor'de çalıştırın.
--
-- ÖNEMLİ: Eğer daha önce user_id olmadan tablolar oluşturduysanız:
-- 1) Önce mevcut tabloları silin: DROP TABLE IF EXISTS portfolio CASCADE; DROP TABLE IF EXISTS transactions CASCADE;
-- 2) Sonra bu dosyanın tamamını çalıştırın.

-- ========== SEÇENEK 1: Yeni tablolar oluştur (tablolar yoksa) ==========
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  symbol TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('buy', 'sell')),
  quantity NUMERIC(15, 4) NOT NULL CHECK (quantity > 0),
  price NUMERIC(15, 4) NOT NULL CHECK (price >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS portfolio (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  symbol TEXT NOT NULL,
  name TEXT NOT NULL,
  total_quantity NUMERIC(15, 4) NOT NULL DEFAULT 0 CHECK (total_quantity >= 0),
  average_cost NUMERIC(15, 4) NOT NULL DEFAULT 0 CHECK (average_cost >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, symbol)
);

-- ========== SEÇENEK 2: Mevcut tablolara user_id ekle (tablolar varsa) ==========
-- Aşağıdaki satırları sadece daha önce tabloları oluşturduysanız çalıştırın:

-- ALTER TABLE transactions ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
-- ALTER TABLE portfolio ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
-- ALTER TABLE portfolio DROP CONSTRAINT IF EXISTS portfolio_pkey;
-- ALTER TABLE portfolio ADD PRIMARY KEY (user_id, symbol);

-- ========== RLS (Row Level Security) Politikaları ==========
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio ENABLE ROW LEVEL SECURITY;

-- transactions politikaları
DROP POLICY IF EXISTS "transactions_select_own" ON transactions;
CREATE POLICY "transactions_select_own" ON transactions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "transactions_insert_own" ON transactions;
CREATE POLICY "transactions_insert_own" ON transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- portfolio politikaları
DROP POLICY IF EXISTS "portfolio_select_own" ON portfolio;
CREATE POLICY "portfolio_select_own" ON portfolio
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "portfolio_insert_own" ON portfolio;
CREATE POLICY "portfolio_insert_own" ON portfolio
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "portfolio_update_own" ON portfolio;
CREATE POLICY "portfolio_update_own" ON portfolio
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "portfolio_delete_own" ON portfolio;
CREATE POLICY "portfolio_delete_own" ON portfolio
  FOR DELETE USING (auth.uid() = user_id);
