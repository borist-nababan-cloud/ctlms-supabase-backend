alter table "public"."delivery_orders" add column "internal_product_id" uuid;

alter table "public"."delivery_orders" add constraint "delivery_orders_internal_product_id_fkey" FOREIGN KEY (internal_product_id) REFERENCES public.master_products(id) not valid;

alter table "public"."delivery_orders" validate constraint "delivery_orders_internal_product_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_do_inventory()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Pastikan internal_product_id tidak null
  IF NEW.internal_product_id IS NULL THEN
    RAISE EXCEPTION 'Internal Product ID tidak boleh kosong untuk pengiriman!';
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
    NEW.internal_product_id, -- Gunakan ID dari field baru
    'STOCKPILE',
    -NEW.net_weight, -- Pengurangan stok
    'SALES_OUT',
    NEW.id,
    NEW.company_id,
    'DO No: ' || NEW.sj_number
  );
  RETURN NEW;
END;
$function$
;


