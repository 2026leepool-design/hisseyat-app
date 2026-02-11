-- Supabase Portfolio ve Transactions Tabloları - Portföy Yönetimi ve Bölünme/Temettü Desteği
-- Bu SQL'i Supabase SQL Editor'de çalıştırın.

-- ========== 1. Portföyler Tablosu ==========
CREATE TABLE IF NOT EXISTS portfolios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, name)
);

-- ========== 2. Portfolio Tablosuna portfolio_id Ekle ==========
ALTER TABLE portfolio ADD COLUMN IF NOT EXISTS portfolio_id UUID REFERENCES portfolios(id) ON DELETE SET NULL;

-- ========== 3. Transactions Tablosuna portfolio_id ve transaction_type Ekle ==========
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS portfolio_id UUID REFERENCES portfolios(id) ON DELETE SET NULL;

-- transaction_type sütunu varsa constraint'i kaldır, yoksa ekle
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'transaction_type') THEN
    -- Sütun varsa, mevcut constraint'i kaldır ve yeniden ekle
    ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
    ALTER TABLE transactions ALTER COLUMN transaction_type DROP DEFAULT;
    ALTER TABLE transactions ALTER COLUMN transaction_type SET DEFAULT 'buy';
    ALTER TABLE transactions ADD CONSTRAINT transactions_transaction_type_check 
      CHECK (transaction_type IN ('buy', 'sell', 'split', 'dividend'));
  ELSE
    -- Sütun yoksa ekle
    ALTER TABLE transactions ADD COLUMN transaction_type TEXT DEFAULT 'buy' 
      CHECK (transaction_type IN ('buy', 'sell', 'split', 'dividend'));
  END IF;
END $$;

-- ========== 4. Transactions Tablosunda quantity ve price nullable yap (temettü için) ==========
ALTER TABLE transactions ALTER COLUMN quantity DROP NOT NULL;
ALTER TABLE transactions ALTER COLUMN price DROP NOT NULL;

-- Mevcut constraint'leri kaldır (varsa)
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_quantity_check;
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_price_check;

-- Yeni constraint'leri ekle
ALTER TABLE transactions ADD CONSTRAINT transactions_quantity_check CHECK (
  (transaction_type IN ('buy', 'sell', 'split') AND quantity IS NOT NULL AND quantity > 0) OR
  (transaction_type = 'dividend' AND quantity IS NULL)
);
ALTER TABLE transactions ADD CONSTRAINT transactions_price_check CHECK (
  (transaction_type IN ('buy', 'sell', 'dividend') AND price IS NOT NULL AND price >= 0) OR
  (transaction_type = 'split' AND price IS NOT NULL AND price >= 0)
);

-- ========== 5. RLS Politikaları - Portföyler ==========
ALTER TABLE portfolios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "portfolios_select_own" ON portfolios;
CREATE POLICY "portfolios_select_own" ON portfolios
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "portfolios_insert_own" ON portfolios;
CREATE POLICY "portfolios_insert_own" ON portfolios
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "portfolios_update_own" ON portfolios;
CREATE POLICY "portfolios_update_own" ON portfolios
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "portfolios_delete_own" ON portfolios;
CREATE POLICY "portfolios_delete_own" ON portfolios
  FOR DELETE USING (auth.uid() = user_id);

-- ========== 6. Index'ler (Performans için) ==========
CREATE INDEX IF NOT EXISTS idx_portfolio_portfolio_id ON portfolio(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_transactions_portfolio_id ON transactions(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_transactions_transaction_type ON transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_portfolios_user_id ON portfolios(user_id);
