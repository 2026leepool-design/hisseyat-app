-- Kripto portföy desteği: portfolios tablosuna asset_type eklenir
-- asset_type: 'stock' = hisse, 'crypto' = kripto para
-- Bu SQL'i Supabase SQL Editor'de çalıştırın.

ALTER TABLE portfolios ADD COLUMN IF NOT EXISTS asset_type TEXT DEFAULT 'stock'
  CHECK (asset_type IN ('stock', 'crypto'));

-- Mevcut portföyler stock kabul edilir
UPDATE portfolios SET asset_type = 'stock' WHERE asset_type IS NULL;
