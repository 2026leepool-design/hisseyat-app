-- Komisyon oranı ve işlem komisyonu desteği
-- Supabase SQL Editor'de çalıştırın.
--
-- ZORUNLU: Satış yaparken "Could not find the 'commission' column" hatası alıyorsanız
-- bu migration'ı Supabase Dashboard > SQL Editor'de çalıştırın.

-- Portföyler tablosuna varsayılan komisyon oranı (binde 1 = 0.001)
ALTER TABLE portfolios ADD COLUMN IF NOT EXISTS commission_rate NUMERIC(10, 6) DEFAULT 0.001;
COMMENT ON COLUMN portfolios.commission_rate IS 'Portföy için varsayılan komisyon oranı (örn. 0.001 = binde 1).';

-- Transactions tablosuna işlem komisyon tutarı
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS commission NUMERIC(15, 4) NULL;
COMMENT ON COLUMN transactions.commission IS 'İşlemde ödenen komisyon tutarı (TL). Alım/satımda kullanılır.';
