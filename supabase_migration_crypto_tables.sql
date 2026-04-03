-- Kripto portföy ve işlem tabloları (hisse tablolarından tamamen ayrı)
-- Sadece alım/satım; bölünme ve temettü yok.
-- Bu SQL'i Supabase SQL Editor'de çalıştırın.

-- ========== 1. Kripto Portföyler ==========
CREATE TABLE IF NOT EXISTS crypto_portfolios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, name)
);

-- ========== 2. Kripto Portföy Pozisyonları (holdings) ==========
CREATE TABLE IF NOT EXISTS crypto_portfolio (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  symbol TEXT NOT NULL,
  name TEXT NOT NULL,
  total_quantity NUMERIC(18, 8) NOT NULL DEFAULT 0 CHECK (total_quantity >= 0),
  average_cost NUMERIC(18, 8) NOT NULL DEFAULT 0 CHECK (average_cost >= 0),
  portfolio_id UUID REFERENCES crypto_portfolios(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Aynı kullanıcı + sembol + portföy (veya portföy null ise tek kayıt) tekil olsun
CREATE UNIQUE INDEX IF NOT EXISTS idx_crypto_portfolio_user_symbol_portfolio
  ON crypto_portfolio (user_id, symbol, COALESCE(portfolio_id::text, '00000000-0000-0000-0000-000000000000'));

-- ========== 3. Kripto İşlemler (sadece buy/sell) ==========
CREATE TABLE IF NOT EXISTS crypto_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  symbol TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('buy', 'sell')),
  quantity NUMERIC(18, 8) NOT NULL CHECK (quantity > 0),
  price NUMERIC(18, 8) NOT NULL CHECK (price >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  portfolio_id UUID REFERENCES crypto_portfolios(id) ON DELETE SET NULL,
  commission NUMERIC(18, 8) NULL,
  satis_kari NUMERIC(18, 8) NULL,
  satis_kar_yuzde NUMERIC(10, 4) NULL
);

-- ========== 4. RLS ==========
ALTER TABLE crypto_portfolios ENABLE ROW LEVEL SECURITY;
ALTER TABLE crypto_portfolio ENABLE ROW LEVEL SECURITY;
ALTER TABLE crypto_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "crypto_portfolios_select_own" ON crypto_portfolios;
CREATE POLICY "crypto_portfolios_select_own" ON crypto_portfolios FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "crypto_portfolios_insert_own" ON crypto_portfolios;
CREATE POLICY "crypto_portfolios_insert_own" ON crypto_portfolios FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "crypto_portfolios_update_own" ON crypto_portfolios;
CREATE POLICY "crypto_portfolios_update_own" ON crypto_portfolios FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "crypto_portfolios_delete_own" ON crypto_portfolios;
CREATE POLICY "crypto_portfolios_delete_own" ON crypto_portfolios FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "crypto_portfolio_select_own" ON crypto_portfolio;
CREATE POLICY "crypto_portfolio_select_own" ON crypto_portfolio FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "crypto_portfolio_insert_own" ON crypto_portfolio;
CREATE POLICY "crypto_portfolio_insert_own" ON crypto_portfolio FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "crypto_portfolio_update_own" ON crypto_portfolio;
CREATE POLICY "crypto_portfolio_update_own" ON crypto_portfolio FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "crypto_portfolio_delete_own" ON crypto_portfolio;
CREATE POLICY "crypto_portfolio_delete_own" ON crypto_portfolio FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "crypto_transactions_select_own" ON crypto_transactions;
CREATE POLICY "crypto_transactions_select_own" ON crypto_transactions FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "crypto_transactions_insert_own" ON crypto_transactions;
CREATE POLICY "crypto_transactions_insert_own" ON crypto_transactions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ========== 5. Index'ler ==========
CREATE INDEX IF NOT EXISTS idx_crypto_portfolio_portfolio_id ON crypto_portfolio(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_crypto_transactions_portfolio_id ON crypto_transactions(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_crypto_portfolios_user_id ON crypto_portfolios(user_id);
