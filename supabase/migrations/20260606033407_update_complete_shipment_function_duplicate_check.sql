set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.complete_shipment(p_shipment_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_shipment RECORD;
BEGIN
  -- 1. Ambil data shipment
  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;

  -- 2. Update shipment status (INI YANG UTAMA)
  UPDATE public.shipments 
  SET is_completed = true, status = 'completed' 
  WHERE id = p_shipment_id;

  -- 3. Masukkan ke ledger (Hanya jika belum masuk sebelumnya)
  -- Kita cek apakah sudah ada ledger dengan reference_id ini
  IF NOT EXISTS (SELECT 1 FROM public.inventory_ledger WHERE reference_id = p_shipment_id) THEN
      INSERT INTO public.inventory_ledger (
        product_id, location, qty_change, transaction_type, reference_id, company_id, notes
      ) VALUES (
        v_shipment.product_id, 'STOCKPILE', v_shipment.quantity, 'TALLY_IN', 
        v_shipment.id, v_shipment.company_id, 'Auto-input from Shipment: ' || v_shipment.invoice_no
      );
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Pengiriman selesai dan stok berhasil ditambah.');
END;
$function$
;


