-- Implement Option B: Support returning stock to different product via return_product_id
--
-- REQUIREMENT: When canceling a DO (RETURN_TOTAL), allow returning stock to a
-- different product than the original, specified via return_product_id.
--
-- APPROACH: Single Source of Truth (Trigger Only)
-- - RPC function: Only updates status and data (NO INSERT into ledger)
-- - Trigger function: Handles ALL ledger entries with two cases:
--   Case A: return_product_id specified → return to that different product
--   Case B: return_product_id NULL → return to original products (fallback)
--
-- This ensures no double entries and maintains architectural consistency.

-- ============================================================
-- STEP 1: RPC Function - Update Data and Status Only (No Direct INSERT)
-- ============================================================
CREATE OR REPLACE FUNCTION public.approve_do_cancellation(p_request_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_req RECORD;
  v_sj_number text;
  v_company_id uuid;
BEGIN
  -- 1. Ambil data request
  SELECT * INTO v_req FROM public.do_cancellation_requests WHERE id = p_request_id;
  IF v_req IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Request tidak ditemukan.');
  END IF;

  -- 2. Ambil data DO (Gunakan variabel skalar agar tidak error "indeterminate")
  SELECT sj_number, company_id INTO v_sj_number, v_company_id
  FROM public.delivery_orders WHERE id = v_req.do_id;

  IF v_sj_number IS NULL THEN
    RAISE EXCEPTION 'Surat Jalan (DO) dengan ID % tidak ditemukan!', v_req.do_id;
  END IF;

  -- 3. Eksekusi perubahan DATA (hanya data, TIDAK melakukan insert ke ledger secara manual)
  IF v_req.request_type = 'Ganti Kendaraan' THEN
    UPDATE public.delivery_orders
    SET truck_plate = v_req.truck_plate, transporter_id = v_req.transporter_id
    WHERE id = v_req.do_id;

  ELSIF v_req.request_type = 'Ganti Sales Order' THEN
    UPDATE public.delivery_orders SET sales_order_id = v_req.sales_order_id WHERE id = v_req.do_id;

  ELSIF v_req.request_type = 'Pengembalian Stok (Total)' THEN
    -- Mengupdate status DO menjadi is_cancel = true
    -- Trigger 'trg_approve_do_cancellation' akan otomatis menangani ledger
    UPDATE public.delivery_orders SET is_cancel = true WHERE id = v_req.do_id;
  END IF;

  -- 4. Update status request
  UPDATE public.do_cancellation_requests
  SET status = 'APPROVED', approved_by = auth.uid()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'message', 'Perubahan berhasil diterapkan.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- STEP 2: Update Trigger to Handle return_product_id (Improved)
-- ============================================================
CREATE OR REPLACE FUNCTION public.approve_do_cancellation()
RETURNS TRIGGER AS $$
DECLARE
  v_do_data RECORD;
  v_sj_number text;
BEGIN
  -- Hanya jalan jika status berubah dari ON_REQUEST ke APPROVED
  IF NEW.status = 'APPROVED' AND OLD.status = 'ON_REQUEST' THEN

    -- Ambil data DO header
    SELECT sj_number, company_id INTO v_sj_number, v_do_data.company_id
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
          'RETURN', NEW.do_id, v_do_data.company_id, 'Return Total to New Product: ' || v_sj_number
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

-- ============================================================
-- STEP 3: Recreate Trigger
-- ============================================================
DROP TRIGGER IF EXISTS trg_approve_do_cancellation ON public.do_cancellation_requests;
CREATE TRIGGER trg_approve_do_cancellation
AFTER UPDATE ON public.do_cancellation_requests
FOR EACH ROW EXECUTE FUNCTION public.approve_do_cancellation();
