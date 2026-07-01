drop view if exists "public"."view_adjustment_report";

create or replace view "public"."view_adjustment_report" as  SELECT adj.id,
    adj.created_at,
    s.invoice_no,
    mp.name AS supplier_name,
    s.vessel_name,
    s.quantity AS invoice_qty,
    prod.name AS product_name,
    adj.current_stock_snapshot AS qty_current,
    adj.actual_stock,
    adj.selisih,
    adj.status,
    adj.notes,
    ( SELECT COALESCE(sum(doi.produk_net), (0)::numeric) AS "coalesce"
           FROM (public.delivery_order_items doi
             JOIN public.delivery_orders d_ord ON ((doi.do_id = d_ord.id)))
          WHERE ((d_ord.shipment_id = adj.shipment_id) AND (d_ord.delivery_type = 'DIRECT'::text))) AS total_qty_loosing,
    up_creator.real_name AS user_create,
    up_approver.real_name AS user_approve
   FROM (((((public.inventory_adjustments adj
     LEFT JOIN public.shipments s ON ((adj.shipment_id = s.id)))
     LEFT JOIN public.master_partners mp ON ((s.supplier_id = mp.id)))
     LEFT JOIN public.master_products prod ON ((adj.product_id = prod.id)))
     LEFT JOIN public.user_profiles up_creator ON ((adj.created_by = up_creator.uuid)))
     LEFT JOIN public.user_profiles up_approver ON ((adj.approved_by = up_approver.uuid)));



