drop view if exists "public"."view_tcp_report";

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



