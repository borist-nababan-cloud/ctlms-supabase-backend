set check_function_bodies = off;

-- Drop function first to allow return type change
DROP FUNCTION IF EXISTS public.approve_inventory_adjustment(p_adjustment_id uuid);

CREATE FUNCTION public.approve_inventory_adjustment(p_adjustment_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_rows_affected int;
BEGIN
  -- Cukup update status saja. Trigger 'trg_adjustment_ledger' akan menangani Ledger.
  UPDATE public.inventory_adjustments
  SET status = 'APPROVED', approved_by = auth.uid()
  WHERE id = p_adjustment_id AND status = 'ON_REQUEST';

  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

  IF v_rows_affected = 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Request tidak ditemukan atau sudah diproses.');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Persetujuan berhasil.');
END;
$function$
;

-- Drop trigger and function first
DROP TRIGGER IF EXISTS trg_adjustment_ledger ON public.inventory_adjustments;
DROP FUNCTION IF EXISTS public.handle_adjustment_ledger();

-- Recreate function
CREATE FUNCTION public.handle_adjustment_ledger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- HANYA jalankan jika status berubah dari ON_REQUEST ke APPROVED
  IF NEW.status = 'APPROVED' AND OLD.status = 'ON_REQUEST' THEN

    INSERT INTO public.inventory_ledger (
      product_id, location, qty_change, transaction_type, reference_id, company_id, notes
    ) VALUES (
      NEW.product_id,
      'STOCKPILE',
      (NEW.actual_stock - NEW.current_stock_snapshot),
      'ADJUST_STOCK',
      NEW.id,
      (SELECT company_id FROM public.user_profiles WHERE uuid = NEW.created_by),
      'Adj: ' || NEW.notes
    );
  END IF;
  RETURN NEW;
END;
$function$
;

-- Recreate trigger with proper conditions
CREATE TRIGGER trg_adjustment_ledger
AFTER UPDATE ON public.inventory_adjustments
FOR EACH ROW EXECUTE FUNCTION public.handle_adjustment_ledger();

