-- Migration: Create master_blending and master_type_production tables
-- These tables manage blending configurations and production types

-- 1. Master Blending
CREATE TABLE public.master_blending (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id uuid REFERENCES public.master_companies(id),
  nama_blending text NOT NULL,
  cost numeric(15,2) DEFAULT 0,
  created_at timestamp with time zone DEFAULT now()
);

-- 2. Master Type Production
CREATE TABLE public.master_type_production (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id uuid REFERENCES public.master_companies(id),
  nama_type text NOT NULL,
  cost numeric(15,2) DEFAULT 0,
  created_at timestamp with time zone DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.master_blending ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_type_production ENABLE ROW LEVEL SECURITY;

-- RLS Policies (Global Access for all authenticated users)
CREATE POLICY "Enable read access for authenticated users" ON public.master_blending
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON public.master_blending
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON public.master_blending
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Enable delete access for authenticated users" ON public.master_blending
  FOR DELETE TO authenticated USING (true);

CREATE POLICY "Enable read access for authenticated users" ON public.master_type_production
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable insert access for authenticated users" ON public.master_type_production
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update access for authenticated users" ON public.master_type_production
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Enable delete access for authenticated users" ON public.master_type_production
  FOR DELETE TO authenticated USING (true);

-- Add comments
COMMENT ON TABLE public.master_blending IS 'Master table for blending configurations';
COMMENT ON TABLE public.master_type_production IS 'Master table for production types';
