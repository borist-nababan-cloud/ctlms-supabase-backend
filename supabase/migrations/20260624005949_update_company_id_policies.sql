-- 1. Tambahkan company_id ke master_partners
ALTER TABLE public.master_partners
ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.master_companies(id);

-- 2. Tambahkan company_id ke master_products
ALTER TABLE public.master_products
ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.master_companies(id);

-- 3. Update RLS Policies agar data terisolasi per perusahaan
-- Policy ini memastikan user hanya bisa melihat data milik perusahaannya
-- (Jika company_id IS NULL, berarti itu data Global yang bisa dilihat semua orang)

DROP POLICY IF EXISTS "Company isolation partners" ON public.master_partners;
CREATE POLICY "Company isolation partners" ON public.master_partners
USING (
  company_id = (SELECT company_id FROM user_profiles WHERE uuid = auth.uid())
  OR company_id IS NULL
);

DROP POLICY IF EXISTS "Company isolation products" ON public.master_products;
CREATE POLICY "Company isolation products" ON public.master_products
USING (
  company_id = (SELECT company_id FROM user_profiles WHERE uuid = auth.uid())
  OR company_id IS NULL
);

-- 1. Pastikan company_id di master_products adalah NULLABLE (optional)
ALTER TABLE public.master_products ALTER COLUMN company_id DROP NOT NULL;

-- 2. Hapus kebijakan isolasi lama yang membatasi akses per perusahaan
DROP POLICY IF EXISTS "Company isolation products" ON public.master_products;

-- 3. Buat kebijakan baru: Semua user terautentikasi bisa membaca dan menambah produk
CREATE POLICY "Allow authenticated read" ON public.master_products FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated write" ON public.master_products FOR ALL TO authenticated USING (true);
