alter table "public"."do_cancellation_requests" drop constraint "do_cancellation_requests_new_sales_order_id_fkey";

alter table "public"."do_cancellation_requests" drop constraint "do_cancellation_requests_new_transporter_id_fkey";

alter table "public"."do_cancellation_requests" drop column "new_sales_order_id";

alter table "public"."do_cancellation_requests" drop column "new_transporter_id";

alter table "public"."do_cancellation_requests" drop column "new_truck_plate";

alter table "public"."do_cancellation_requests" add column "sales_order_id" uuid;

alter table "public"."do_cancellation_requests" add column "transporter_id" uuid;

alter table "public"."do_cancellation_requests" add column "truck_plate" text;

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_new_sales_order_id_fkey" FOREIGN KEY (sales_order_id) REFERENCES public.sales_orders(id) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_new_sales_order_id_fkey";

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_new_transporter_id_fkey" FOREIGN KEY (transporter_id) REFERENCES public.master_partners(id) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_new_transporter_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.approve_do_cancellation(p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$ DECLARE v_req RECORD; BEGIN SELECT * INTO v_req FROM public.do_cancellation_requests WHERE id = p_request_id; IF v_req IS NULL THEN RETURN jsonb_build_object('success', false, 'message', 'Request ID tidak ditemukan.'); END IF; IF v_req.request_type = 'Ganti Kendaraan' THEN UPDATE public.delivery_orders SET truck_plate = COALESCE(v_req.truck_plate, truck_plate), transporter_id = COALESCE(v_req.transporter_id, transporter_id) WHERE id = v_req.do_id; IF NOT FOUND THEN RAISE EXCEPTION 'Gagal: ID Surat Jalan (%) tidak ditemukan!', v_req.do_id; END IF; ELSIF v_req.request_type = 'Ganti Sales Order' THEN UPDATE public.delivery_orders SET sales_order_id = v_req.sales_order_id WHERE id = v_req.do_id; END IF; UPDATE public.do_cancellation_requests SET status = 'APPROVED', approved_by = auth.uid() WHERE id = p_request_id; RETURN jsonb_build_object('success', true, 'message', 'Perubahan berhasil.'); END; $function$
;


