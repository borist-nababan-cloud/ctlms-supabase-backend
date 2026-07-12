drop view if exists "public"."view_adjustment_report";

drop view if exists "public"."view_delivery_report";

drop view if exists "public"."view_tcp_report";

create or replace view "public"."view_adjustment_report" as  SELECT adj.id,
    adj.company_id,
    adj.product_id,
    adj.current_stock_snapshot,
    adj.actual_stock,
    adj.status,
    adj.notes,
    adj.created_by,
    adj.approved_by,
    adj.created_at,
    adj.rejection_notes,
    adj.selisih,
    adj.shipment_id,
    s.invoice_no,
    mp.name AS supplier_name,
    s.vessel_name,
    prod.name AS product_name,
    up.real_name AS created_by_name
   FROM ((((public.inventory_adjustments adj
     LEFT JOIN public.shipments s ON ((adj.shipment_id = s.id)))
     LEFT JOIN public.master_partners mp ON ((s.supplier_id = mp.id)))
     LEFT JOIN public.master_products prod ON ((adj.product_id = prod.id)))
     LEFT JOIN public.user_profiles up ON ((adj.created_by = up.uuid)));


create or replace view "public"."view_delivery_report" as  SELECT d_ord.id,
    d_ord.created_at,
    d_ord.sales_order_id,
    d_ord.truck_plate,
    d_ord.ticket_number,
    d_ord.net_weight,
    d_ord.photo_url,
    d_ord.created_by,
    d_ord.company_id,
    d_ord.date_of_issue,
    d_ord.gross_terima,
    d_ord.gross_weight,
    d_ord.net_terima,
    d_ord.shipment_id,
    d_ord.sj_number,
    d_ord.tare_terima,
    d_ord.tare_weight,
    d_ord.vessel_name,
    d_ord.published_product_name,
    d_ord.internal_product_id,
    d_ord.delivery_type,
    d_ord.is_blending,
    d_ord.blending_id,
    d_ord.type_blending,
    d_ord.transporter_id,
    d_ord.adjust_weight,
    d_ord.is_cancel,
    so.order_no,
    so.po_number,
    mp.name AS customer_name,
    prod.name AS internal_product_name,
    up.real_name AS created_by_name
   FROM (((((public.delivery_orders d_ord
     JOIN public.sales_orders so ON ((d_ord.sales_order_id = so.id)))
     JOIN public.delivery_order_items doi ON ((d_ord.id = doi.do_id)))
     JOIN public.master_products prod ON ((doi.internal_product_id = prod.id)))
     LEFT JOIN public.master_partners mp ON ((so.customer_id = mp.id)))
     LEFT JOIN public.user_profiles up ON ((d_ord.created_by = up.uuid)));


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
    s.invoice_no,
    mp.name AS supplier_name,
    s.vessel_name,
    prod.name AS product_name,
    up.real_name AS created_by_name
   FROM ((((public.tcp_input t
     LEFT JOIN public.shipments s ON ((t.shipment_id = s.id)))
     LEFT JOIN public.master_partners mp ON ((s.supplier_id = mp.id)))
     LEFT JOIN public.master_products prod ON ((t.product_id = prod.id)))
     LEFT JOIN public.user_profiles up ON ((t.created_by = up.uuid)));



