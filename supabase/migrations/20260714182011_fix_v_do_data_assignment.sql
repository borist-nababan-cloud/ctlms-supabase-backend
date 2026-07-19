-- Fix v_do_data assignment error in trigger
CREATE OR REPLACE FUNCTION public.approve_do_cancellation()
RETURNS TRIGGER AS $$
DECLARE
  v_sj_number text;
  v_company_id uuid;
BEGIN
  -- Hanya jalan jika status berubah dari ON_REQUEST ke APPROVED
  IF NEW.status = 'APPROVED' AND OLD.status = 'ON_REQUEST' THEN

    -- Ambil data DO header
    SELECT sj_number, company_id INTO v_sj_number, v_company_id
    FROM public.delivery_orders WHERE id = NEW.do_id;

    -- LOGIKA: Pengembalian Stok (Total)
    IF NEW.request_type = 'Pengembalian Stok (Total)' THEN

      -- A. Jika user memilih produk tujuan baru (return_product_id diisi)
      IF NEW.return_product_id IS NOT NULL THEN
        INSERT INTO public.inventory_ledger (
          product_id, location, qty_change, transaction_type, reference_id, company_id, notes
        ) VALUES (
          NEW.return_product_id, 'STOCKPILE',
          (SELECT net_weight FROM public.delivery_orders WHERE id = NEW.do_id),
          'RETURN', NEW.do_id, v_company_id, 'Return Total to New Product: ' || v_sj_number
        );

      -- B. Else: Kembalikan ke produk asli (LEGACY/FALLBACK)
      ELSE
        INSERT INTO public.inventory_ledger (
          product_id, location, qty_change, transaction_type, reference_id, company_id, notes
        )
        SELECT
          internal_product_id, 'STOCKPILE', produk_net, 'RETURN', do_id,
          (SELECT company_id FROM public.delivery_orders WHERE id = do_id),
          'Return Total: ' || v_sj_number
        FROM public.delivery_order_items WHERE do_id = NEW.do_id;
      END IF;

      -- C. Update DO Header
      UPDATE public.delivery_orders SET is_cancel = true WHERE id = NEW.do_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
