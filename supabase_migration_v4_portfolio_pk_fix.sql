-- Portfolio Tablosu Primary Key Düzeltmesi
-- Aynı hissenin farklı portföylerde tutulabilmesi için
-- Bu SQL'i Supabase SQL Editor'de çalıştırın.

-- Mevcut primary key (user_id, symbol) aynı hissenin sadece bir portföyde olmasını zorunlu kılıyordu.
-- Yeni şema: (user_id, symbol, portfolio_id) benzersiz olacak - aynı hisse farklı portföylerde tutulabilir.

-- ========== 1. Eski primary key'i kaldır ==========
ALTER TABLE portfolio DROP CONSTRAINT IF EXISTS portfolio_pkey;

-- ========== 2. id sütunu ekle (yeni primary key için) ==========
ALTER TABLE portfolio ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();

-- Mevcut satırlara id ata (NULL olanlar için)
UPDATE portfolio SET id = gen_random_uuid() WHERE id IS NULL;

-- id'yi NOT NULL yap
ALTER TABLE portfolio ALTER COLUMN id SET NOT NULL;

-- ========== 3. Yeni primary key ==========
ALTER TABLE portfolio ADD PRIMARY KEY (id);

-- ========== 4. Benzersizlik kısıtı: (user_id, symbol, portfolio_id) ==========
-- Aynı hisse farklı portföylerde tutulabilir.
-- portfolio_id NULL ise (eski Ana Portföy verisi) tek satır kalır.
DROP INDEX IF EXISTS portfolio_user_symbol_portfolio_uniq;
CREATE UNIQUE INDEX portfolio_user_symbol_portfolio_uniq ON portfolio (
  user_id,
  symbol,
  COALESCE(portfolio_id::text, '00000000-0000-0000-0000-000000000000')
);
