-- Add transporter_id and adjust_weight columns to delivery_orders
-- Created: June 16, 2026

-- 1. Add transporter_id column (references master_partners)
ALTER TABLE public.delivery_orders
ADD COLUMN IF NOT EXISTS transporter_id uuid REFERENCES public.master_partners(id);

-- 2. Add adjust_weight column (defaults to 0)
ALTER TABLE public.delivery_orders
ADD COLUMN IF NOT EXISTS adjust_weight numeric DEFAULT 0;

-- 3. Add index for transporter_id search optimization
CREATE INDEX IF NOT EXISTS idx_do_transporter ON public.delivery_orders(transporter_id);
