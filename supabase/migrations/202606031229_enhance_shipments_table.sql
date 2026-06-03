-- Migration: Enhance shipments table with company isolation and additional columns
-- This migration adds financial tracking, dates, and company-based access control

-- 1. Remove old status constraint (we're using boolean is_completed instead)
ALTER TABLE public.shipments DROP CONSTRAINT IF EXISTS shipments_status_check;

-- 2. Add required columns
ALTER TABLE public.shipments
ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.master_companies(id),
ADD COLUMN IF NOT EXISTS issue_date date,
ADD COLUMN IF NOT EXISTS loading_date date,
ADD COLUMN IF NOT EXISTS qty_loading numeric DEFAULT 0, -- Will be auto-updated by system
ADD COLUMN IF NOT EXISTS harga numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS ppn_tax numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS pph_tax numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS disc numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_completed boolean DEFAULT false;

-- 3. Update RLS Policy (Only company admins can see their company's data)
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Company isolation" ON public.shipments;
CREATE POLICY "Company isolation" ON public.shipments
USING (company_id = (SELECT company_id FROM user_profiles WHERE uuid = auth.uid()));

-- Add comments
COMMENT ON COLUMN public.shipments.company_id IS 'Company reference for multi-tenant isolation';
COMMENT ON COLUMN public.shipments.issue_date IS 'Date when shipment was issued';
COMMENT ON COLUMN public.shipments.loading_date IS 'Date when loading began';
COMMENT ON COLUMN public.shipments.qty_loading IS 'Loading quantity (auto-updated by system)';
COMMENT ON COLUMN public.shipments.harga IS 'Base price/amount';
COMMENT ON COLUMN public.shipments.ppn_tax IS 'PPN (VAT) tax amount';
COMMENT ON COLUMN public.shipments.pph_tax IS 'PPh (income tax) amount';
COMMENT ON COLUMN public.shipments.disc IS 'Discount amount';
COMMENT ON COLUMN public.shipments.is_completed IS 'Shipment completion status flag';
