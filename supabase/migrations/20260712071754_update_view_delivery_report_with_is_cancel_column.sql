drop view if exists "public"."view_delivery_report";

create or replace view "public"."view_delivery_report" as  SELECT d_ord.id,
    d_ord.company_id,
    d_ord.is_cancel,
    d_ord.created_at,
    so.order_no,
    so.po_number,
    d_ord.sj_number,
    d_ord.delivery_type,
    mp.name AS customer_name,
    so.product_name AS published_product,
    prod.name AS internal_product_name,
    doi.produk_net AS qty_kg,
    d_ord.type_blending,
    mtp.nama_type AS type_production,
    tp.name AS transporter_name,
    doi.truck_plate
   FROM ((((((public.delivery_orders d_ord
     JOIN public.sales_orders so ON ((d_ord.sales_order_id = so.id)))
     JOIN public.delivery_order_items doi ON ((d_ord.id = doi.do_id)))
     JOIN public.master_partners mp ON ((so.customer_id = mp.id)))
     JOIN public.master_products prod ON ((doi.internal_product_id = prod.id)))
     LEFT JOIN public.master_type_production mtp ON ((doi.type_production_id = mtp.id)))
     LEFT JOIN public.master_partners tp ON ((d_ord.transporter_id = tp.id)));



