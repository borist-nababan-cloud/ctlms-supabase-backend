set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.approve_do_cancellation(p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$ DECLARE v_req RECORD; v_old_company_id uuid; v_new_company_id uuid; v_new_sj text; BEGIN SELECT * INTO v_req FROM public.do_cancellation_requests WHERE id = p_request_id; IF v_req IS NULL THEN RETURN jsonb_build_object('success', false, 'message', 'Request ID tidak ditemukan.'); END IF; SELECT company_id INTO v_old_company_id FROM public.delivery_orders WHERE id = v_req.do_id; IF v_req.request_type = 'Ganti Sales Order' THEN SELECT company_id INTO v_new_company_id FROM public.sales_orders WHERE id = v_req.sales_order_id; IF v_old_company_id != v_new_company_id THEN v_new_sj := public.generate_sj_number(v_new_company_id); UPDATE public.delivery_orders SET sales_order_id = v_req.sales_order_id, company_id = v_new_company_id, sj_number = v_new_sj WHERE id = v_req.do_id; ELSE UPDATE public.delivery_orders SET sales_order_id = v_req.sales_order_id WHERE id = v_req.do_id; END IF; END IF; UPDATE public.do_cancellation_requests SET status = 'APPROVED', approved_by = auth.uid() WHERE id = p_request_id; RETURN jsonb_build_object('success', true, 'message', 'Perubahan berhasil diterapkan.'); END; $function$
;


