drop view if exists "public"."view_tcp_report";

alter table "public"."tcp_input" add column "approved_at" timestamp with time zone;

alter table "public"."tcp_input" add column "approved_by" uuid;

alter table "public"."tcp_input" add constraint "tcp_input_approved_by_fkey" FOREIGN KEY (approved_by) REFERENCES auth.users(id) not valid;

alter table "public"."tcp_input" validate constraint "tcp_input_approved_by_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.approve_tcp_input(p_tcp_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_tcp RECORD;
BEGIN
  -- Ambil data tcp_input
  SELECT * INTO v_tcp FROM public.tcp_input WHERE id = p_tcp_id;
  
  -- Update status & approved_by
  UPDATE public.tcp_input
  SET status = 'APPROVED', 
      approved_by = auth.uid(),
      approved_at = now()
  WHERE id = p_tcp_id;

  -- Insert ke ledger (Reconciliation)
  INSERT INTO public.inventory_ledger (
    product_id, location, qty_change, transaction_type, reference_id, company_id, notes
  ) VALUES (
    v_tcp.product_id, 'STOCKPILE', v_tcp.selisih, 'ADJUST_STOCK', 
    v_tcp.id, v_tcp.company_id, 'TCP Reconciliation: ' || v_tcp.notes
  );

  RETURN jsonb_build_object('success', true, 'message', 'TCP Berhasil Disetujui');
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



