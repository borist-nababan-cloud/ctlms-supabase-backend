-- 1. Update Trigger untuk Pengadaan (Shipment)
CREATE OR REPLACE FUNCTION public.handle_shipment_completed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_completed = true AND (OLD.is_completed = false OR OLD.is_completed IS NULL) THEN
    INSERT INTO public.inventory_ledger (
      product_id, location, qty_change, transaction_type, reference_id, company_id, notes
    ) VALUES (
      NEW.product_id, 'STOCKPILE', NEW.quantity, 'TALLY_IN',
      NEW.id, NEW.company_id, 'Auto from shipment ' || NEW.vessel_name
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update Trigger untuk Penjualan (Direct & Stockpile)
CREATE OR REPLACE FUNCTION public.handle_do_inventory_detail()
RETURNS TRIGGER AS $$
DECLARE
  v_do_data RECORD;
BEGIN
  -- Handle delete operations early to prevent accessing NEW (which is null)
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  -- Ambil data header (delivery_orders) untuk tahu tipe pengiriman dan no SJ
  SELECT sj_number, delivery_type INTO v_do_data
  FROM public.delivery_orders WHERE id = NEW.do_id;

  INSERT INTO public.inventory_ledger (
    id,
    product_id,
    location,
    qty_change,
    transaction_type,
    reference_id,
    company_id,
    notes
  ) VALUES (
    NEW.id,
    NEW.internal_product_id,
    'STOCKPILE',
    -NEW.produk_net,
    'SALES_OUT',
    NEW.do_id,
    (SELECT company_id FROM public.delivery_orders WHERE id = NEW.do_id),
    'Sales (' || COALESCE(v_do_data.delivery_type, 'NONE') || ') from ' || COALESCE(v_do_data.sj_number, '')
  )
  ON CONFLICT (id) DO UPDATE SET
    product_id = EXCLUDED.product_id,
    qty_change = EXCLUDED.qty_change,
    company_id = EXCLUDED.company_id,
    notes = EXCLUDED.notes;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update Trigger untuk Penyesuaian (Adjustment & TCP)
CREATE OR REPLACE FUNCTION public.handle_adjustment_ledger()
RETURNS TRIGGER AS $$
BEGIN
  -- Jalankan trigger hanya jika status berubah menjadi APPROVED
  IF NEW.status = 'APPROVED' AND (OLD.status IS DISTINCT FROM 'APPROVED') THEN
    INSERT INTO public.inventory_ledger (
      product_id, location, qty_change, transaction_type, reference_id, company_id, notes
    ) VALUES (
      NEW.product_id, 'STOCKPILE', (NEW.actual_stock - NEW.current_stock_snapshot),
      'ADJUSTMENT', NEW.id, NEW.company_id, NEW.notes
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_adjustment_ledger ON public.inventory_adjustments;
CREATE TRIGGER trg_adjustment_ledger
AFTER UPDATE ON public.inventory_adjustments
FOR EACH ROW EXECUTE FUNCTION public.handle_adjustment_ledger();
