-- Fix Double Entry Issue in complete_shipment
--
-- PROBLEM: The RPC function was doing BOTH status update AND direct INSERT into inventory_ledger
-- while the trigger 'on_shipment_completed' was also doing INSERT on status change.
-- This caused double entries with inconsistent transaction types (TALLY_IN vs PEMBELIAN).
--
-- SOLUTION: RPC function now ONLY updates status. The trigger handles the ledger entry.
-- Transaction type is now consistently 'PEMBELIAN' for all shipment completions.

-- Update the RPC function to remove direct INSERT into inventory_ledger
CREATE OR REPLACE FUNCTION public.complete_shipment(p_shipment_id uuid)
RETURNS jsonb AS $$
BEGIN
  -- Update status saja. Trigger 'on_shipment_completed' akan mendeteksi perubahan ini
  -- dan otomatis memasukkan data ke inventory_ledger dengan tipe 'PEMBELIAN'.
  UPDATE public.shipments
  SET is_completed = true, status = 'completed'
  WHERE id = p_shipment_id AND (is_completed = false OR is_completed IS NULL);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Shipment tidak ditemukan atau sudah selesai.');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Pengiriman selesai.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: The trigger 'on_shipment_completed' calling 'handle_shipment_completed' remains unchanged.
-- It will continue to handle the INSERT into inventory_ledger with transaction_type = 'PEMBELIAN'.
-- This ensures single source of truth and consistent transaction typing.
