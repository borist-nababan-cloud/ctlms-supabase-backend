-- 1. Master Companies
CREATE TABLE public.master_companies (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);
-- Menambahkan kolom baru ke tabel master_companies
ALTER TABLE public.master_companies 
ADD COLUMN IF NOT EXISTS address1 text,
ADD COLUMN IF NOT EXISTS address2 text,
ADD COLUMN IF NOT EXISTS city text,
ADD COLUMN IF NOT EXISTS province text,
ADD COLUMN IF NOT EXISTS zipcode text,
ADD COLUMN IF NOT EXISTS pic_name text,
ADD COLUMN IF NOT EXISTS fixline text,
ADD COLUMN IF NOT EXISTS mobile text,
ADD COLUMN IF NOT EXISTS email text;