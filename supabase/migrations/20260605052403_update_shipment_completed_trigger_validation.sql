drop trigger if exists "on_shipment_completed" on "public"."shipments";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_shipment_completed()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Debugging: Cek apakah trigger dipanggil
  RAISE NOTICE 'Trigger dipanggil untuk ID: %', NEW.id;

  -- Logic: Hanya jika is_completed berubah menjadi true
  IF (NEW.is_completed = true AND (OLD.is_completed = false OR OLD.is_completed IS NULL)) THEN

    -- Cek jika company_id ada
    IF NEW.company_id IS NULL THEN
        RAISE EXCEPTION 'Gagal: company_id tidak boleh kosong!';
    END IF;

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

CREATE TRIGGER on_shipment_completed AFTER UPDATE ON public.shipments FOR EACH ROW EXECUTE FUNCTION public.handle_shipment_completed();


