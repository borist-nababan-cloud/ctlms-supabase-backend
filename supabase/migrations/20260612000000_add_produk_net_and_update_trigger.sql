-- Add produk_net column to delivery_order_items
ALTER TABLE public.delivery_order_items
ADD COLUMN IF NOT EXISTS produk_net numeric DEFAULT 0;

-- Add type_blending column to delivery_orders with CHECK constraint
ALTER TABLE public.delivery_orders
ADD COLUMN IF NOT EXISTS type_blending text DEFAULT 'NONE' CHECK (type_blending IN ('NONE', 'BLENDING TUMPUK', 'BLENDING BAWAH'));

-- Update trigger function to use produk_net for inventory deduction
CREATE OR REPLACE FUNCTION public.handle_do_inventory_detail()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id uuid;
BEGIN
  -- Ambil company_id dari delivery_orders header
  SELECT company_id INTO v_company_id FROM public.delivery_orders WHERE id = NEW.do_id;

  -- Insert inventory ledger entry using produk_net
  INSERT INTO public.inventory_ledger (
    product_id, location, qty_change, transaction_type, reference_id, company_id, notes
  ) VALUES (
    NEW.internal_product_id,
    'STOCKPILE',
    -NEW.produk_net, -- MEMOTONG STOK BERDASARKAN PRODUK_NET
    'SALES_OUT',
    NEW.do_id,
    v_company_id,
    'DO Item Truck ' || NEW.truck_plate
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
