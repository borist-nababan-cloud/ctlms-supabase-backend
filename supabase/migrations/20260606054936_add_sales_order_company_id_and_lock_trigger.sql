alter table "public"."sales_orders" add column "company_id" uuid;

alter table "public"."sales_orders" add column "is_completed" boolean default false;

alter table "public"."sales_orders" add constraint "sales_orders_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.master_companies(id) not valid;

alter table "public"."sales_orders" validate constraint "sales_orders_company_id_fkey";

set check_function_bodies = off;

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

CREATE TRIGGER trg_lock_completed_sales_order BEFORE DELETE OR UPDATE ON public.sales_orders FOR EACH ROW EXECUTE FUNCTION public.check_sales_order_lock();


