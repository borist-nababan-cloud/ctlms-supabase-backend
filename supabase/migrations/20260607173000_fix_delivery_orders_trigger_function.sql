-- Fix handle_do_inventory function to reference correct table (sales_orders not master_sales_order)
CREATE OR REPLACE FUNCTION public.handle_do_inventory()
RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.inventory_ledger (
    product_id, location, qty_change, transaction_type, reference_id, company_id, notes
  ) VALUES (
    (SELECT product_id FROM public.sales_orders WHERE id = NEW.sales_order_id),
    'STOCKPILE',
    -NEW.net_weight, -- Mengurangi stok
    'SALES_OUT',
    NEW.id,
    NEW.company_id,
    'DO No: ' || NEW.sj_number
  );
  RETURN NEW;
END;
$function$
;
