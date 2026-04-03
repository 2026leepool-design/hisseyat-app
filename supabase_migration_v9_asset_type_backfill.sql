-- Hisse portföylerinin görünmesi için: asset_type NULL olan tüm portföyleri 'stock' yap.
-- Bu migration'ı Supabase SQL Editor'de çalıştırın (v8'ü çalıştırdıysanız zaten yapılmış olabilir).

-- Kolon yoksa ekle (v8 ile aynı)
ALTER TABLE portfolios ADD COLUMN IF NOT EXISTS asset_type TEXT DEFAULT 'stock';

-- Constraint yoksa ekle (PostgreSQL'de IF NOT EXISTS constraint için farklı syntax gerekebilir)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'portfolios_asset_type_check'
  ) THEN
    ALTER TABLE portfolios ADD CONSTRAINT portfolios_asset_type_check
      CHECK (asset_type IN ('stock', 'crypto'));
  END IF;
END $$;

-- Mevcut tüm portföylerde NULL ise 'stock' yap (hisse uygulaması bunları göstersin)
UPDATE portfolios SET asset_type = 'stock' WHERE asset_type IS NULL;
