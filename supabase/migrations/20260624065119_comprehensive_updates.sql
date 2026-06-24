alter table "public"."inventory_ledger" drop constraint "inventory_ledger_transaction_type_check";

alter table "public"."master_companies" add column "type_sj" smallint default '1'::smallint;

alter table "public"."inventory_ledger" add constraint "inventory_ledger_transaction_type_check" CHECK ((transaction_type = ANY (ARRAY['TALLY_IN'::text, 'SALES_OUT'::text, 'ADJUSTMENT'::text, 'PEMBELIAN'::text, 'SALES_STOCK_PILE'::text, 'TCP_INPUT'::text, 'RETURN'::text, 'SALES_LOOSING'::text]))) not valid;

alter table "public"."inventory_ledger" validate constraint "inventory_ledger_transaction_type_check";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_do_inventory_detail()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_company_id uuid;
  v_delivery_type text;
BEGIN
  -- Ambil company_id dan delivery_type dari Header
  SELECT company_id, delivery_type INTO v_company_id, v_delivery_type 
  FROM public.delivery_orders WHERE id = NEW.do_id;

  INSERT INTO public.inventory_ledger (
    product_id, location, qty_change, transaction_type, reference_id, company_id, notes
  ) VALUES (
    NEW.internal_product_id,
    'STOCKPILE',
    -NEW.produk_net, 
    -- Logika otomatis menentukan tipe transaksi
    CASE 
      WHEN v_delivery_type = 'DIRECT' THEN 'SALES_LOOSING' 
      ELSE 'SALES_STOCK_PILE' 
    END,
    NEW.do_id,
    v_company_id,
    'DO Item Truck ' || NEW.truck_plate
  );
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_shipment_completed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Hanya jalan jika status berubah menjadi Completed
  IF NEW.is_completed = true AND (OLD.is_completed = false OR OLD.is_completed IS NULL) THEN
    
    -- Insert ke ledger dengan transaction_type: 'PEMBELIAN'
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
      NEW.quantity, -- Stok bertambah
      'PEMBELIAN', -- Update ke PEMBELIAN
      NEW.id, 
      NEW.company_id, 
      'Auto from shipment ' || COALESCE(NEW.vessel_name, 'No Vessel')
    );
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE TRIGGER on_shipment_completed AFTER UPDATE ON public.shipments FOR EACH ROW EXECUTE FUNCTION public.handle_shipment_completed();


