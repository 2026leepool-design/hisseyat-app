-- Satış işlemlerinde ortalama maliyet üzerinden kar (TL) ve hisse başı kar % kaydı
-- Supabase SQL Editor'de çalıştırın.

ALTER TABLE transactions ADD COLUMN IF NOT EXISTS satis_kari NUMERIC(15, 4) NULL;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS satis_kar_yuzde NUMERIC(10, 2) NULL;

COMMENT ON COLUMN transactions.satis_kari IS 'Satış anındaki ortalama maliyet üzerinden hesaplanan kar/zarar (TL). Sadece sell işlemleri için dolu.';
COMMENT ON COLUMN transactions.satis_kar_yuzde IS 'Hisse başına kar/zarar yüzdesi (ortalama maliyete göre). Sadece sell işlemleri için dolu.';
