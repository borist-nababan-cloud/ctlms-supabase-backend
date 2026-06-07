alter table "public"."sales_orders" add column "product_name" text;

alter table "public"."sales_orders" alter column "price_per_kg" set default 0;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_sales_completed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NEW.is_completed = true AND (OLD.is_completed = false OR OLD.is_completed IS NULL) THEN
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
      -NEW.qty_ordered,
      'SALES_OUT',
      NEW.id,
      NEW.company_id,
      'Auto-input from Sales Order: ' || NEW.order_no
    );
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE TRIGGER trg_sales_completed AFTER UPDATE ON public.sales_orders FOR EACH ROW EXECUTE FUNCTION public.handle_sales_completed();


