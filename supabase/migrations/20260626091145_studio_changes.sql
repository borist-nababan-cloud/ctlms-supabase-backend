drop view if exists "public"."view_inventory_current";

set check_function_bodies = off;

create or replace view "public"."view_delivery_report" as  SELECT d_ord.id,
    d_ord.company_id,
    d_ord.created_at,
    so.order_no,
    d_ord.sj_number,
    d_ord.delivery_type,
    mp.name AS customer_name,
    so.product_name AS published_product,
    prod.name AS internal_product_name,
    doi.produk_net AS qty_kg,
    d_ord.type_blending,
    mtp.nama_type AS type_production
   FROM (((((public.delivery_orders d_ord
     JOIN public.sales_orders so ON ((d_ord.sales_order_id = so.id)))
     JOIN public.delivery_order_items doi ON ((d_ord.id = doi.do_id)))
     JOIN public.master_partners mp ON ((so.customer_id = mp.id)))
     JOIN public.master_products prod ON ((doi.internal_product_id = prod.id)))
     LEFT JOIN public.master_type_production mtp ON ((doi.type_production_id = mtp.id)));


create or replace view "public"."view_ledger_details" as  SELECT il.id,
    il.created_at,
    il.product_id,
    il.location,
    il.qty_change,
    il.transaction_type,
    il.reference_id,
    il.notes,
    il.company_id,
    s.vessel_name,
    mp.name AS supplier_name,
    prod.name AS product_name
   FROM (((public.inventory_ledger il
     LEFT JOIN public.shipments s ON ((il.reference_id = s.id)))
     LEFT JOIN public.master_partners mp ON ((s.supplier_id = mp.id)))
     LEFT JOIN public.master_products prod ON ((il.product_id = prod.id)));


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

create or replace view "public"."view_inventory_current" as  SELECT p.id AS product_id,
    p.sku_code,
    p.name AS product_name,
    il.company_id,
    COALESCE(sum(il.qty_change), (0)::numeric) AS current_stock_kg
   FROM (public.master_products p
     LEFT JOIN public.inventory_ledger il ON ((p.id = il.product_id)))
  GROUP BY p.id, p.sku_code, p.name, il.company_id;



