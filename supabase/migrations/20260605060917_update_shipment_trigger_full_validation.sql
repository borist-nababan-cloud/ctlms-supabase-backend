set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_shipment_completed()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Cek apakah status berubah menjadi Completed
  IF (NEW.is_completed = true) AND (OLD.is_completed = false OR OLD.is_completed IS NULL) THEN

    -- Validasi: Jika data penting kosong, lempar error agar terlihat di console/network
    IF NEW.product_id IS NULL THEN RAISE EXCEPTION 'Gagal: Product ID kosong!'; END IF;
    IF NEW.quantity IS NULL OR NEW.quantity = 0 THEN RAISE EXCEPTION 'Gagal: Quantity kosong!'; END IF;
    IF NEW.company_id IS NULL THEN RAISE EXCEPTION 'Gagal: Company ID kosong!'; END IF;

    INSERT INTO public.inventory_ledger (
      product_id,
      location,
      qty_change,
      transaction_type,
      reference_id,
      company_id,
      notes
    ) VALUES (
      NEW.product_id,
      'STOCKPILE',
      NEW.quantity,
      'TALLY_IN',
      NEW.id,
      NEW.company_id,
      'Auto-input from Shipment: ' || NEW.invoice_no
    );
  END IF;

  RETURN NEW;
END;
$function$
;


