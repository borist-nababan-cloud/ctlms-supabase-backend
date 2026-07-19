-- Fix Double Entry Issue in approve_do_cancellation
--
-- PROBLEM: The RPC function was doing BOTH status update AND direct INSERT into inventory_ledger
-- while the trigger was also doing INSERT on status change, causing duplicate entries.
--
-- SOLUTION: RPC function now ONLY updates status and modifies data. The trigger handles ledger.
-- For RETURN_ALL, we use the existing trg_revert_inventory_on_delete trigger by deleting items.

-- Update the RPC function to remove direct INSERT into inventory_ledger
CREATE OR REPLACE FUNCTION public.approve_do_cancellation(p_request_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_req RECORD;
BEGIN
  -- 1. Ambil data request
  SELECT * INTO v_req FROM public.do_cancellation_requests WHERE id = p_request_id;

  -- 2. Update status request (PENTING: Lakukan ini dulu)
  UPDATE public.do_cancellation_requests
  SET status = 'APPROVED', approved_by = auth.uid()
  WHERE id = p_request_id;

  -- 3. Eksekusi perubahan DATA (hanya data, TANPA menyentuh inventory_ledger)
  IF v_req.request_type = 'CHANGE_TRUCK' THEN
    UPDATE public.delivery_orders
    SET truck_plate = v_req.truck_plate, transporter_id = v_req.transporter_id
    WHERE id = v_req.do_id;

  ELSIF v_req.request_type = 'CHANGE_SO' THEN
    UPDATE public.delivery_orders SET sales_order_id = v_req.sales_order_id WHERE id = v_req.do_id;

  ELSIF v_req.request_type = 'RETURN_ALL' THEN
    -- Untuk RETURN_ALL, kita hapus detail DO agar trigger 'trg_revert_inventory_on_delete' berjalan
    -- Trigger akan otomatis memotong stok masuk (Reversal) karena trigger tersebut mendeteksi DELETE
    DELETE FROM public.delivery_order_items WHERE do_id = v_req.do_id;
    UPDATE public.delivery_orders SET is_cancel = true WHERE id = v_req.do_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Perubahan berhasil diterapkan.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: The trigger version (approve_do_cancellation() RETURNS trigger) remains unchanged
-- and will continue to handle the RETURN_ALL case for direct status updates via Studio.
-- The key fix is that this RPC version no longer does duplicate INSERT operations.
