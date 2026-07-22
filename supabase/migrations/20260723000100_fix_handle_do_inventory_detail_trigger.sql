-- Fix handle_do_inventory_detail trigger with improved variable handling
-- Created: July 23, 2026

-- Update the function with scalar variables instead of RECORD type
CREATE OR REPLACE FUNCTION public.handle_do_inventory_detail()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id uuid;
  v_sj_number text;
  v_delivery_type text;
BEGIN
  -- 1. Ambil data header DO dengan variabel terpisah (Skalar), bukan RECORD
  SELECT company_id, sj_number, delivery_type
  INTO v_company_id, v_sj_number, v_delivery_type
  FROM public.delivery_orders
  WHERE id = NEW.do_id;

  -- 2. Keamanan: Jika DO Header tidak ditemukan, hentikan proses (Jangan crash)
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  -- 3. Insert ke ledger
  INSERT INTO public.inventory_ledger (
    product_id, location, qty_change, transaction_type, reference_id, company_id, notes
  ) VALUES (
    NEW.internal_product_id,
    'STOCKPILE',
    -NEW.produk_net,
    CASE
      WHEN v_delivery_type = 'DIRECT' THEN 'SALES_LOOSING'
      ELSE 'SALES_STOCK_PILE'
    END,
    NEW.do_id,
    v_company_id,
    'Sales from ' || COALESCE(v_sj_number, 'Unknown')
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
DROP TRIGGER IF EXISTS trg_do_inventory_detail ON public.delivery_order_items;
CREATE TRIGGER trg_do_inventory_detail
  AFTER INSERT ON public.delivery_order_items
  FOR EACH ROW EXECUTE FUNCTION public.handle_do_inventory_detail();
