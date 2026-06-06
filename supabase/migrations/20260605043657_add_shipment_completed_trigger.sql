set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_shipment_completed()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Hanya jalan jika status berubah dari tidak selesai ke selesai
  IF NEW.is_completed = true AND (OLD.is_completed = false OR OLD.is_completed IS NULL) THEN

    -- 1. Automatisasi Status (Database housekeeping)
    NEW.status := 'completed';

    -- 2. Automatisasi Inventory
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

CREATE TRIGGER on_shipment_completed BEFORE UPDATE ON public.shipments FOR EACH ROW EXECUTE FUNCTION public.handle_shipment_completed();


