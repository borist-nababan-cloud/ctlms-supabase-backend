set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.approve_do_cancellation(p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_do_id uuid;
  v_request_type text;
  v_truck_plate text;
  v_transporter_id uuid;
  v_sales_order_id uuid;
  v_sj_number text;
  v_company_id uuid;
BEGIN
  -- 1. Ambil data request ke variabel skalar (bukan RECORD)
  SELECT do_id, request_type, truck_plate, transporter_id, sales_order_id 
  INTO v_do_id, v_request_type, v_truck_plate, v_transporter_id, v_sales_order_id
  FROM public.do_cancellation_requests WHERE id = p_request_id;
  
  IF v_do_id IS NULL THEN 
    RETURN jsonb_build_object('success', false, 'message', 'Request ID tidak ditemukan.'); 
  END IF;

  -- 2. Ambil data DO header (Gunakan SELECT tunggal untuk variabel skalar)
  SELECT sj_number, company_id INTO v_sj_number, v_company_id
  FROM public.delivery_orders WHERE id = v_do_id;

  IF v_sj_number IS NULL THEN
    RAISE EXCEPTION 'Surat Jalan (DO) dengan ID % tidak ditemukan!', v_do_id;
  END IF;

  -- 3. Eksekusi perubahan
  IF v_request_type = 'Ganti Kendaraan' THEN
    UPDATE public.delivery_orders 
    SET truck_plate = v_truck_plate, transporter_id = v_transporter_id 
    WHERE id = v_do_id;
    
  ELSIF v_request_type = 'Ganti Sales Order' THEN
    UPDATE public.delivery_orders SET sales_order_id = v_sales_order_id WHERE id = v_do_id;
    
  ELSIF v_request_type = 'Pengembalian Stok (Total)' THEN
    UPDATE public.delivery_orders SET is_cancel = true WHERE id = v_do_id;
  END IF;

  -- 4. Update status request
  UPDATE public.do_cancellation_requests 
  SET status = 'APPROVED', approved_by = auth.uid() 
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'message', 'Perubahan berhasil.');
END;
$function$
;


