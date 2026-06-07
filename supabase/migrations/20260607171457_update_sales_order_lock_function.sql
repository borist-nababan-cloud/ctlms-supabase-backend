-- Update sales order lock function to check for completed status
CREATE OR REPLACE FUNCTION public.check_sales_order_lock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF (OLD.is_completed = true OR OLD.status = 'COMPLETED') THEN
    IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE uuid = auth.uid() AND user_role = 8) THEN
      RAISE EXCEPTION 'Data terkunci: Transaksi ini sudah selesai dan tidak dapat diubah.';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trg_lock_completed_sales_order ON public.sales_orders;

-- Create trigger to lock completed sales orders
CREATE TRIGGER trg_lock_completed_sales_order BEFORE DELETE OR UPDATE ON public.sales_orders FOR EACH ROW EXECUTE FUNCTION public.check_sales_order_lock();
