drop view if exists "public"."view_ledger_details";

alter table "public"."inventory_adjustments" add column "selisih" numeric default 0;

alter table "public"."inventory_adjustments" add column "shipment_id" uuid;

alter table "public"."tcp_input" add column "created_by" uuid;

alter table "public"."inventory_adjustments" add constraint "inventory_adjustments_shipment_id_fkey" FOREIGN KEY (shipment_id) REFERENCES public.shipments(id) not valid;

alter table "public"."inventory_adjustments" validate constraint "inventory_adjustments_shipment_id_fkey";

alter table "public"."tcp_input" add constraint "tcp_input_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) not valid;

alter table "public"."tcp_input" validate constraint "tcp_input_created_by_fkey";

create or replace view "public"."view_adjustment_report" as  SELECT adj.id,
    adj.created_at,
    s.invoice_no,
    mp.name AS supplier_name,
    s.vessel_name,
    prod.name AS product_name,
    adj.current_stock_snapshot AS qty_current,
    adj.actual_stock,
    adj.selisih,
    adj.status,
    adj.notes,
    COALESCE(up_creator.real_name, (u_creator.email)::text, 'Unknown'::text) AS user_create,
    COALESCE(up_approver.real_name, (u_approver.email)::text, '-'::text) AS user_approve
   FROM (((((((public.inventory_adjustments adj
     LEFT JOIN public.shipments s ON ((adj.shipment_id = s.id)))
     LEFT JOIN public.master_partners mp ON ((s.supplier_id = mp.id)))
     LEFT JOIN public.master_products prod ON ((adj.product_id = prod.id)))
     LEFT JOIN auth.users u_creator ON ((adj.created_by = u_creator.id)))
     LEFT JOIN auth.users u_approver ON ((adj.approved_by = u_approver.id)))
     LEFT JOIN public.user_profiles up_creator ON ((u_creator.id = up_creator.uuid)))
     LEFT JOIN public.user_profiles up_approver ON ((u_approver.id = up_approver.uuid)));


create or replace view "public"."view_tcp_report" as  SELECT t.id,
    t.created_at,
    t.company_id,
    s.invoice_no,
    mp.name AS supplier_name,
    s.vessel_name,
    prod.name AS product_name,
    t.theoretical_stock AS qty_invoice,
    t.tcp_value AS qty_tcp,
    t.total_out,
    t.theoretical_stock AS stock_system,
    t.actual_stock,
    t.selisih,
    u.email AS user_create,
    t.notes
   FROM ((((public.tcp_input t
     LEFT JOIN public.shipments s ON ((t.shipment_id = s.id)))
     LEFT JOIN public.master_partners mp ON ((s.supplier_id = mp.id)))
     LEFT JOIN public.master_products prod ON ((t.product_id = prod.id)))
     LEFT JOIN auth.users u ON ((t.created_by = u.id)));


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
    mp_sup.name AS supplier_name,
    d_ord.sj_number,
    mp_cust.name AS customer_name,
    prod.name AS product_name
   FROM ((((((public.inventory_ledger il
     LEFT JOIN public.shipments s ON (((il.reference_id = s.id) AND (il.transaction_type = 'PEMBELIAN'::text))))
     LEFT JOIN public.master_partners mp_sup ON ((s.supplier_id = mp_sup.id)))
     LEFT JOIN public.delivery_orders d_ord ON (((il.reference_id = d_ord.id) AND (il.transaction_type = ANY (ARRAY['SALES_LOOSING'::text, 'SALES_STOCK_PILE'::text])))))
     LEFT JOIN public.sales_orders so ON ((d_ord.sales_order_id = so.id)))
     LEFT JOIN public.master_partners mp_cust ON ((so.customer_id = mp_cust.id)))
     LEFT JOIN public.master_products prod ON ((il.product_id = prod.id)));



