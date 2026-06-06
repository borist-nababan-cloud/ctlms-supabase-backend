drop trigger if exists "on_shipment_completed" on "public"."shipments";

drop function if exists "public"."handle_shipment_completed"();

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.complete_shipment(p_shipment_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_shipment RECORD;
  v_result jsonb;
BEGIN
  -- Ambil data shipment
  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;

  -- Validasi apakah sudah selesai
  IF v_shipment.is_completed = true THEN
    RETURN jsonb_build_object('success', false, 'message', 'Pengiriman sudah selesai sebelumnya.');
  END IF;

  -- 1. Update Shipment menjadi completed
  UPDATE public.shipments
  SET is_completed = true, status = 'completed'
  WHERE id = p_shipment_id;

  -- 2. Masukkan ke ledger (Tambah stok)
  INSERT INTO public.inventory_ledger (
    product_id,
    location,
    qty_change,
    transaction_type,
    reference_id,
    company_id,
    notes
  ) VALUES (
    v_shipment.product_id,
    'STOCKPILE',
    v_shipment.quantity,
    'TALLY_IN',
    v_shipment.id,
    v_shipment.company_id,
    'Auto-input from Shipment: ' || v_shipment.invoice_no
  );

  RETURN jsonb_build_object('success', true, 'message', 'Pengiriman selesai dan stok berhasil ditambah.');
END;
$function$
;


