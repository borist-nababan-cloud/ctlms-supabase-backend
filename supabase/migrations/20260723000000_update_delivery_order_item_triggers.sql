-- Update delivery_order_item triggers with NULL safety and improved logic
-- Created: July 23, 2026

-- 1. Perbaiki trigger untuk hapus (Reversal)
CREATE OR REPLACE FUNCTION public.revert_inventory_on_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- HANYA jalankan jika internal_product_id ADA (bukan NULL)
  IF OLD.internal_product_id IS NOT NULL THEN
    INSERT INTO public.inventory_ledger (
      product_id, location, qty_change, transaction_type, reference_id, company_id, notes
    ) VALUES (
      OLD.internal_product_id,
      'STOCKPILE',
      OLD.produk_net,
      'ADJUSTMENT',
      OLD.do_id,
      (SELECT company_id FROM public.delivery_orders WHERE id = OLD.do_id),
      'REVERSAL: Cancelled DO ' || (SELECT sj_number FROM public.delivery_orders WHERE id = OLD.do_id)
    );
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Perbaiki trigger untuk insert (Sales Out)
CREATE OR REPLACE FUNCTION public.handle_do_inventory_detail()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id uuid;
  v_do_data RECORD;
BEGIN
  -- Pastikan internal_product_id tidak null sebelum insert
  IF NEW.internal_product_id IS NULL THEN
    RETURN NEW; -- Skip jika product ID tidak ada
  END IF;

  SELECT company_id, sj_number, delivery_type INTO v_company_id, v_do_data.sj_number, v_do_data.delivery_type
  FROM public.delivery_orders WHERE id = NEW.do_id;

  INSERT INTO public.inventory_ledger (
    product_id, location, qty_change, transaction_type, reference_id, company_id, notes
  ) VALUES (
    NEW.internal_product_id,
    'STOCKPILE',
    -NEW.produk_net,
    CASE WHEN v_do_data.delivery_type = 'DIRECT' THEN 'SALES_LOOSING' ELSE 'SALES_STOCK_PILE' END,
    NEW.do_id,
    v_company_id,
    'Sales from ' || v_do_data.sj_number
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update triggers to use the updated functions
DROP TRIGGER IF EXISTS trg_revert_inventory_on_delete ON public.delivery_order_items;
CREATE TRIGGER trg_revert_inventory_on_delete
  AFTER DELETE ON public.delivery_order_items
  FOR EACH ROW EXECUTE FUNCTION public.revert_inventory_on_delete();

DROP TRIGGER IF EXISTS trg_do_inventory_detail ON public.delivery_order_items;
CREATE TRIGGER trg_do_inventory_detail
  AFTER INSERT ON public.delivery_order_items
  FOR EACH ROW EXECUTE FUNCTION public.handle_do_inventory_detail();
