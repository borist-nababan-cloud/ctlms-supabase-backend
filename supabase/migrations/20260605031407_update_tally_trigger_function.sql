drop trigger if exists "on_tally_insert" on "public"."trucking_logs";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_new_tally_log()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  target_product_id uuid;
  total_net_weight numeric;
  curr_shipment_id uuid;
BEGIN
  -- Dapatkan shipment_id yang sedang diproses
  curr_shipment_id := COALESCE(NEW.shipment_id, OLD.shipment_id);

  -- Cari product_id yang terkait dengan shipment ini
  SELECT product_id INTO target_product_id
  FROM public.shipments
  WHERE id = curr_shipment_id;

  -- Tambahkan ke Inventory Ledger (hanya jika aksi INSERT baru)
  IF (TG_OP = 'INSERT') THEN
    INSERT INTO public.inventory_ledger (
      product_id,
      location,
      qty_change,
      transaction_type,
      reference_id,
      notes
    ) VALUES (
      target_product_id,
      'STOCKPILE',
      NEW.net_weight,
      'TALLY_IN',
      NEW.shipment_id,
      'Auto-generated from Truck ' || NEW.truck_plate
    );
  END IF;

  -- Hitung total net_weight yang terkumpul dari trucking_logs untuk shipment_id ini
  SELECT COALESCE(SUM(net_weight), 0) INTO total_net_weight
  FROM public.trucking_logs
  WHERE shipment_id = curr_shipment_id;

  -- Perbarui kolom qty_loading di tabel shipments
  UPDATE public.shipments
  SET qty_loading = total_net_weight
  WHERE id = curr_shipment_id;

  -- Kembalikan record yang sesuai
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$function$
;

CREATE TRIGGER on_tally_insert AFTER INSERT OR DELETE OR UPDATE ON public.trucking_logs FOR EACH ROW EXECUTE FUNCTION public.handle_new_tally_log();


