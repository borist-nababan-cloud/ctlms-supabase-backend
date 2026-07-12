alter table "public"."delivery_orders" add column "is_cancel" boolean default false;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.approve_do_cancellation(p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$ DECLARE v_req RECORD; v_item RECORD; BEGIN SELECT * INTO v_req FROM public.do_cancellation_requests WHERE id = p_request_id; UPDATE public.do_cancellation_requests SET status = 'APPROVED', approved_by = auth.uid() WHERE id = p_request_id; IF v_req.request_type = 'Ganti Kendaraan' THEN UPDATE public.delivery_orders SET truck_plate = v_req.truck_plate, transporter_id = v_req.transporter_id WHERE id = v_req.do_id; ELSIF v_req.request_type = 'Ganti Sales Order' THEN UPDATE public.delivery_orders SET sales_order_id = v_req.sales_order_id WHERE id = v_req.do_id; ELSIF v_req.request_type = 'Pengembalian Stok (Total)' THEN UPDATE public.delivery_orders SET is_cancel = true WHERE id = v_req.do_id; FOR v_item IN SELECT * FROM public.delivery_order_items WHERE do_id = v_req.do_id LOOP INSERT INTO public.inventory_ledger (product_id, location, qty_change, transaction_type, reference_id, company_id, notes) VALUES (v_item.internal_product_id, 'STOCKPILE', v_item.produk_net, 'RETURN', v_req.do_id, (SELECT company_id FROM public.delivery_orders WHERE id = v_req.do_id), 'REVERSAL: Cancelled DO ' || (SELECT sj_number FROM public.delivery_orders WHERE id = v_req.do_id)); END LOOP; END IF; RETURN jsonb_build_object('success', true, 'message', 'Proses berhasil.'); END; $function$
;


