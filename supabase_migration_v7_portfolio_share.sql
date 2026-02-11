-- Portföy paylaşımı için profiles ve portfolio_shares tabloları
-- Supabase SQL Editor'de çalıştırın.

-- ========== 1. Profiles Tablosu (auth.users ile senkron) ==========
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Mevcut kullanıcıları profiles'a ekle
INSERT INTO public.profiles (id, email)
SELECT id, email FROM auth.users
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;

-- Yeni kullanıcı kaydında otomatik profile oluştur
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Profiles: giriş yapmış kullanıcılar kendi profilini ve diğerlerinin email'ini görebilir (paylaşım için)
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (auth.role() = 'authenticated');

-- ========== 2. Portfolio Shares Tablosu ==========
CREATE TABLE IF NOT EXISTS public.portfolio_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id UUID NOT NULL REFERENCES public.portfolios(id) ON DELETE CASCADE,
  owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shared_with_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  permission TEXT NOT NULL CHECK (permission IN ('readonly', 'edit')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(portfolio_id, shared_with_user_id)
);

CREATE INDEX IF NOT EXISTS idx_portfolio_shares_portfolio_id ON public.portfolio_shares(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_shares_shared_with ON public.portfolio_shares(shared_with_user_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_shares_owner ON public.portfolio_shares(owner_user_id);

ALTER TABLE public.portfolio_shares ENABLE ROW LEVEL SECURITY;

-- Sahip: kendi paylaşımlarını yönetebilir
DROP POLICY IF EXISTS "portfolio_shares_owner_all" ON public.portfolio_shares;
CREATE POLICY "portfolio_shares_owner_all" ON public.portfolio_shares
  FOR ALL USING (auth.uid() = owner_user_id)
  WITH CHECK (auth.uid() = owner_user_id);

-- Paylaşılan kişi: kendi erişimini kaldırabilir (DELETE)
DROP POLICY IF EXISTS "portfolio_shares_shared_delete_own" ON public.portfolio_shares;
CREATE POLICY "portfolio_shares_shared_delete_own" ON public.portfolio_shares
  FOR DELETE USING (auth.uid() = shared_with_user_id);

-- Paylaşılan kişi: kendi paylaşım kaydını okuyabilir (SELECT)
DROP POLICY IF EXISTS "portfolio_shares_shared_select" ON public.portfolio_shares;
CREATE POLICY "portfolio_shares_shared_select" ON public.portfolio_shares
  FOR SELECT USING (auth.uid() = shared_with_user_id OR auth.uid() = owner_user_id);

-- ========== 3. Portfolios - Paylaşım erişimi (SELECT) ==========
DROP POLICY IF EXISTS "portfolios_select_shared" ON public.portfolios;
CREATE POLICY "portfolios_select_shared" ON public.portfolios
  FOR SELECT USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.portfolio_shares ps
      WHERE ps.portfolio_id = portfolios.id
      AND ps.shared_with_user_id = auth.uid()
    )
  );

-- ========== 4. Portfolio ve Transactions - Paylaşım erişimi ==========
-- Paylaşılan portföy verisine erişim (portfolio tablosu)
DROP POLICY IF EXISTS "portfolio_select_shared" ON public.portfolio;
CREATE POLICY "portfolio_select_shared" ON public.portfolio
  FOR SELECT USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.portfolio_shares ps
      WHERE ps.portfolio_id = portfolio.portfolio_id
      AND ps.shared_with_user_id = auth.uid()
    )
  );

-- Paylaşılan portföyde düzenleme (edit yetkisi varsa)
DROP POLICY IF EXISTS "portfolio_insert_shared" ON public.portfolio;
CREATE POLICY "portfolio_insert_shared" ON public.portfolio
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.portfolio_shares ps
      WHERE ps.portfolio_id = portfolio.portfolio_id
      AND ps.shared_with_user_id = auth.uid()
      AND ps.permission = 'edit'
    )
  );

DROP POLICY IF EXISTS "portfolio_update_shared" ON public.portfolio;
CREATE POLICY "portfolio_update_shared" ON public.portfolio
  FOR UPDATE USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.portfolio_shares ps
      WHERE ps.portfolio_id = portfolio.portfolio_id
      AND ps.shared_with_user_id = auth.uid()
      AND ps.permission = 'edit'
    )
  );

-- Transactions: paylaşım erişimi
DROP POLICY IF EXISTS "transactions_select_shared" ON public.transactions;
CREATE POLICY "transactions_select_shared" ON public.transactions
  FOR SELECT USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.portfolio_shares ps
      WHERE ps.portfolio_id = transactions.portfolio_id
      AND ps.shared_with_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "transactions_insert_shared" ON public.transactions;
CREATE POLICY "transactions_insert_shared" ON public.transactions
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.portfolio_shares ps
      WHERE ps.portfolio_id = transactions.portfolio_id
      AND ps.shared_with_user_id = auth.uid()
      AND ps.permission = 'edit'
    )
  );

DROP POLICY IF EXISTS "transactions_update_shared" ON public.transactions;
CREATE POLICY "transactions_update_shared" ON public.transactions
  FOR UPDATE USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.portfolio_shares ps
      WHERE ps.portfolio_id = transactions.portfolio_id
      AND ps.shared_with_user_id = auth.uid()
      AND ps.permission = 'edit'
    )
  );
