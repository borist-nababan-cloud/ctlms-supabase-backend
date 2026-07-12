alter table "public"."do_cancellation_requests" enable row level security;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.approve_do_cancellation(p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$ DECLARE v_req RECORD; BEGIN SELECT * INTO v_req FROM public.do_cancellation_requests WHERE id = p_request_id; IF v_req IS NULL THEN RETURN jsonb_build_object('success', false, 'message', 'Request ID tidak ditemukan.'); END IF; IF v_req.request_type = 'Ganti Kendaraan' THEN UPDATE public.delivery_orders SET truck_plate = COALESCE(v_req.truck_plate, truck_plate), transporter_id = COALESCE(v_req.transporter_id, transporter_id) WHERE id = v_req.do_id; IF NOT FOUND THEN RAISE EXCEPTION 'Gagal: ID Surat Jalan (%) tidak ditemukan!', v_req.do_id; END IF; ELSIF v_req.request_type = 'Ganti Sales Order' THEN UPDATE public.delivery_orders SET sales_order_id = v_req.sales_order_id WHERE id = v_req.do_id; END IF; UPDATE public.do_cancellation_requests SET status = 'APPROVED', approved_by = auth.uid() WHERE id = p_request_id; RETURN jsonb_build_object('success', true, 'message', 'Perubahan berhasil.'); END; $function$
;


  create policy "DO Cancellation Access"
  on "public"."do_cancellation_requests"
  as permissive
  for all
  to authenticated
using (((( SELECT user_profiles.user_role
   FROM public.user_profiles
  WHERE (user_profiles.uuid = auth.uid())) = ANY (ARRAY[(1)::bigint, (8)::bigint])) OR (company_id = ( SELECT user_profiles.company_id
   FROM public.user_profiles
  WHERE (user_profiles.uuid = auth.uid())))));



  create policy "Sales Order Access"
  on "public"."sales_orders"
  as permissive
  for all
  to authenticated
using (((( SELECT user_profiles.user_role
   FROM public.user_profiles
  WHERE (user_profiles.uuid = auth.uid())) = ANY (ARRAY[(1)::bigint, (8)::bigint])) OR ((current_setting('request.method'::text, true) = 'GET'::text) AND true) OR (company_id = ( SELECT user_profiles.company_id
   FROM public.user_profiles
  WHERE (user_profiles.uuid = auth.uid())))));



