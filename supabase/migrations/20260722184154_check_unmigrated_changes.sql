drop view if exists "public"."view_tcp_report";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_do_inventory_detail()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_company_id uuid;
  v_sj_number text;
  v_delivery_type text;
BEGIN
  SELECT company_id, sj_number, delivery_type
  INTO v_company_id, v_sj_number, v_delivery_type
  FROM public.delivery_orders
  WHERE id = NEW.do_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.inventory_ledger (
    product_id, location, qty_change, transaction_type, reference_id, company_id, notes
  ) VALUES (
    NEW.internal_product_id,
    'STOCKPILE',
    -NEW.produk_net,
    CASE
      WHEN v_delivery_type = 'DIRECT' THEN 'SALES_LOOSING'
      ELSE 'SALES_STOCK_PILE'
    END,
    NEW.do_id,
    v_company_id,
    'Sales from ' || COALESCE(v_sj_number, 'Unknown')
  );

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.revert_inventory_on_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF OLD.internal_product_id IS NOT NULL THEN
    INSERT INTO public.inventory_ledger (
      product_id, location, qty_change, transaction_type, reference_id, company_id, notes
    ) VALUES (
      OLD.internal_product_id,
      'STOCKPILE',
      OLD.produk_net,
      'ADJUSTMENT',
      OLD.do_id,
      (SELECT company_id FROM public.delivery_orders WHERE id = OLD.do_id),
      'REVERSAL: Cancelled DO ' || (SELECT sj_number FROM public.delivery_orders WHERE id = OLD.do_id)
    );
  END IF;
  RETURN OLD;
END;
$function$
;

create or replace view "public"."view_tcp_report" as  SELECT t.id,
    t.shipment_id,
    t.product_id,
    t.tcp_value,
    t.total_in,
    t.total_out,
    t.actual_stock,
    t.current_stock_snapshot,
    t.inventory_adjustment_id,
    t.notes,
    t.created_at,
    t.company_id,
    t.rejection_notes,
    t.status,
    t.actual_stock_system,
    t.selisih,
    t.theoretical_stock,
    t.created_by,
    t.approved_by,
    t.approved_at,
    s.invoice_no,
    s.quantity AS invoice_qty,
    mp.name AS supplier_name,
    s.vessel_name,
    prod.name AS product_name,
    u_creator.real_name AS user_create,
    u_approver.real_name AS user_approve
   FROM (((((public.tcp_input t
     LEFT JOIN public.shipments s ON ((t.shipment_id = s.id)))
     LEFT JOIN public.master_partners mp ON ((s.supplier_id = mp.id)))
     LEFT JOIN public.master_products prod ON ((t.product_id = prod.id)))
     LEFT JOIN public.user_profiles u_creator ON ((t.created_by = u_creator.uuid)))
     LEFT JOIN public.user_profiles u_approver ON ((t.approved_by = u_approver.uuid)));



