-- Migration: Add tcp_input table and shipments foreign key
-- Created: June 17, 2026
-- Description: Creates tcp_input table for tracking TCP (Total Coal Production) values and links it to shipments

-- 1. Buat tabel tcp_input
CREATE TABLE public.tcp_input (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  shipment_id uuid REFERENCES public.shipments(id),
  product_id uuid REFERENCES public.master_products(id),
  tcp_value numeric DEFAULT 0,
  total_in numeric DEFAULT 0,
  total_out numeric DEFAULT 0,
  actual_stock numeric DEFAULT 0,
  current_stock_snapshot numeric DEFAULT 0,
  inventory_adjustment_id uuid REFERENCES public.inventory_adjustments(id), -- Link ke proses approval
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  company_id uuid REFERENCES public.master_companies(id)
);

-- 2. Tambahkan kolom id_tcp ke shipments (relasi 1:1)
ALTER TABLE public.shipments
ADD COLUMN IF NOT EXISTS id_tcp uuid REFERENCES public.tcp_input(id);

-- 3. Policy RLS (Hanya admin/user yang berwenang)
ALTER TABLE public.tcp_input ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Full access" ON public.tcp_input FOR ALL TO authenticated USING (true);
