-- Update approve_do_cancellation function to simplified version
-- This version relies on triggers to handle inventory ledger entries instead of manual inserts
-- Key changes:
-- 1. Added NULL check for request
-- 2. Added validation for DO existence
-- 3. Removed manual inventory_ledger insert (trigger handles this)
-- 4. Moved status update to the end

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
    RETURN jsonb_build_object('success', false, 'message', 'Request ID tidak ditemukan.');
  END IF;

  -- 2. Ambil data DO header menggunakan variabel eksplisit (menghindari error record)
  SELECT sj_number, company_id INTO v_sj_number, v_company_id
  FROM public.delivery_orders WHERE id = v_req.do_id;

  IF v_sj_number IS NULL THEN
    RAISE EXCEPTION 'Surat Jalan dengan ID % tidak ditemukan!', v_req.do_id;
  END IF;

  -- 3. Eksekusi perubahan berdasarkan request_type
  IF v_req.request_type = 'Ganti Kendaraan' THEN
    UPDATE public.delivery_orders
    SET truck_plate = v_req.truck_plate, transporter_id = v_req.transporter_id
    WHERE id = v_req.do_id;

  ELSIF v_req.request_type = 'Ganti Sales Order' THEN
    UPDATE public.delivery_orders SET sales_order_id = v_req.sales_order_id WHERE id = v_req.do_id;

  ELSIF v_req.request_type = 'Pengembalian Stok (Total)' THEN
    -- Update Header menjadi cancelled
    UPDATE public.delivery_orders SET is_cancel = true WHERE id = v_req.do_id;
  END IF;

  -- 4. Update status request
  UPDATE public.do_cancellation_requests
  SET status = 'APPROVED', approved_by = auth.uid()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'message', 'Perubahan berhasil diterapkan.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Refresh API
NOTIFY pgrst, 'reload config';
