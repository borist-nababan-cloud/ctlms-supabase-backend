-- Migration: Add Delivery Order Items Table and Update Inventory Trigger
-- Created: June 10, 2026
-- Description:
--   - Removes old trigger from delivery_orders table
--   - Creates delivery_order_items table for line items
--   - Creates new trigger on delivery_order_items for inventory deduction

-- 1. Hapus trigger lama yang mungkin terpasang di delivery_orders (jika ada)
DROP TRIGGER IF EXISTS trg_do_inventory ON public.delivery_orders;
DROP FUNCTION IF EXISTS public.handle_do_inventory();

-- 2. Create delivery_order_items table
CREATE TABLE IF NOT EXISTS public.delivery_order_items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  do_id uuid REFERENCES public.delivery_orders(id) ON DELETE CASCADE,
  internal_product_id uuid REFERENCES public.master_products(id),
  type_production_id uuid REFERENCES public.master_type_production(id),
  blending_id uuid REFERENCES public.master_blending(id),
  truck_plate text,
  gross_weight numeric DEFAULT 0,
  tare_weight numeric DEFAULT 0,
  net_weight numeric DEFAULT 0,
  photo_url text,
  created_at timestamp with time zone DEFAULT now()
);

-- 3. Create new trigger function for inventory deduction (watches delivery_order_items)
CREATE OR REPLACE FUNCTION public.handle_do_inventory_detail()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id uuid;
BEGIN
  -- Ambil company_id dari Header (delivery_orders)
  SELECT company_id INTO v_company_id FROM public.delivery_orders WHERE id = NEW.do_id;

  INSERT INTO public.inventory_ledger (
    product_id, location, qty_change, transaction_type, reference_id, company_id, notes
  ) VALUES (
    NEW.internal_product_id,
    'STOCKPILE',
    -NEW.net_weight, -- Pengurangan stok
    'SALES_OUT',
    NEW.do_id,
    v_company_id,
    'DO Item Truck ' || NEW.truck_plate
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create trigger on delivery_order_items
DROP TRIGGER IF EXISTS trg_do_inventory_detail ON public.delivery_order_items;
CREATE TRIGGER trg_do_inventory_detail
AFTER INSERT ON public.delivery_order_items
FOR EACH ROW EXECUTE FUNCTION public.handle_do_inventory_detail();
