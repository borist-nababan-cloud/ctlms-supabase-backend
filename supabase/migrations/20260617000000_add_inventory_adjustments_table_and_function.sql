-- Migration: Add inventory_adjustments table and approval function
-- Created: June 17, 2026
-- Description: Creates inventory adjustment request system with approval workflow

-- 1. Tabel Adjustment Request
CREATE TABLE public.inventory_adjustments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id uuid REFERENCES public.master_companies(id),
  product_id uuid REFERENCES public.master_products(id),
  current_stock_snapshot numeric NOT NULL, -- Stok sistem saat request dibuat
  actual_stock numeric NOT NULL, -- Stok fisik yang diinput user
  status text CHECK (status IN ('ON_REQUEST', 'APPROVED', 'REJECTED')) DEFAULT 'ON_REQUEST',
  notes text,
  created_by uuid REFERENCES auth.users(id) DEFAULT auth.uid(),
  approved_by uuid REFERENCES auth.users(id),
  created_at timestamp with time zone DEFAULT now()
);

-- 2. Fungsi untuk Eksekusi Approval (Ini yang memotong/menambah stok)
CREATE OR REPLACE FUNCTION public.approve_inventory_adjustment(p_adjustment_id uuid)
RETURNS void AS $$
DECLARE
  v_row RECORD;
  v_delta numeric;
BEGIN
  -- Ambil data request
  SELECT * INTO v_row FROM public.inventory_adjustments WHERE id = p_adjustment_id;

  IF v_row.status != 'ON_REQUEST' THEN
    RAISE EXCEPTION 'Request sudah diproses sebelumnya.';
  END IF;

  -- Hitung selisih (Delta)
  v_delta := v_row.actual_stock - v_row.current_stock_snapshot;

  -- Update status request
  UPDATE public.inventory_adjustments
  SET status = 'APPROVED', approved_by = auth.uid()
  WHERE id = p_adjustment_id;

  -- Insert ke Ledger
  INSERT INTO public.inventory_ledger (
    product_id, location, qty_change, transaction_type, reference_id, company_id, notes
  ) VALUES (
    v_row.product_id, 'STOCKPILE', v_delta, 'ADJUSTMENT', p_adjustment_id, v_row.company_id, 'Adj: ' || v_row.notes
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE public.inventory_adjustments ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Allow authenticated users to manage adjustments
CREATE POLICY "Authenticated users can view inventory adjustments" ON public.inventory_adjustments
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert inventory adjustments" ON public.inventory_adjustments
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update inventory adjustments" ON public.inventory_adjustments
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete inventory adjustments" ON public.inventory_adjustments
  FOR DELETE USING (auth.role() = 'authenticated');
