
  create table "public"."do_cancellation_requests" (
    "id" uuid not null default gen_random_uuid(),
    "do_id" uuid,
    "request_type" text,
    "new_truck_plate" text,
    "new_transporter_id" uuid,
    "new_sales_order_id" uuid,
    "return_product_id" uuid,
    "notes" text,
    "status" text default 'ON_REQUEST'::text,
    "created_by" uuid default auth.uid(),
    "approved_by" uuid,
    "created_at" timestamp with time zone default now()
      );


CREATE UNIQUE INDEX do_cancellation_requests_pkey ON public.do_cancellation_requests USING btree (id);

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_pkey" PRIMARY KEY using index "do_cancellation_requests_pkey";

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_approved_by_fkey" FOREIGN KEY (approved_by) REFERENCES auth.users(id) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_approved_by_fkey";

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_created_by_fkey";

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_do_id_fkey" FOREIGN KEY (do_id) REFERENCES public.delivery_orders(id) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_do_id_fkey";

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_new_sales_order_id_fkey" FOREIGN KEY (new_sales_order_id) REFERENCES public.sales_orders(id) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_new_sales_order_id_fkey";

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_new_transporter_id_fkey" FOREIGN KEY (new_transporter_id) REFERENCES public.master_partners(id) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_new_transporter_id_fkey";

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_request_type_check" CHECK ((request_type = ANY (ARRAY['CHANGE_TRUCK'::text, 'CHANGE_SO'::text, 'RETURN_ITEM'::text, 'RETURN_ALL'::text]))) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_request_type_check";

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_return_product_id_fkey" FOREIGN KEY (return_product_id) REFERENCES public.master_products(id) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_return_product_id_fkey";

alter table "public"."do_cancellation_requests" add constraint "do_cancellation_requests_status_check" CHECK ((status = ANY (ARRAY['ON_REQUEST'::text, 'APPROVED'::text, 'REJECTED'::text]))) not valid;

alter table "public"."do_cancellation_requests" validate constraint "do_cancellation_requests_status_check";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.approve_do_cancellation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NEW.status = 'APPROVED' AND OLD.status = 'ON_REQUEST' THEN
    -- A. Jika CHANGE_TRUCK: Update delivery_orders
    IF NEW.request_type = 'CHANGE_TRUCK' THEN
      UPDATE public.delivery_orders
      SET truck_plate = NEW.new_truck_plate, transporter_id = NEW.new_transporter_id
      WHERE id = NEW.do_id;
    END IF;

    -- B. Jika CHANGE_SO: Update delivery_orders
    IF NEW.request_type = 'CHANGE_SO' THEN
      UPDATE public.delivery_orders SET sales_order_id = NEW.new_sales_order_id WHERE id = NEW.do_id;
    END IF;

    -- C. Jika RETURN_ALL: Masukkan ke ledger (Return Stock)
    IF NEW.request_type = 'RETURN_ALL' THEN
      INSERT INTO public.inventory_ledger (product_id, location, qty_change, transaction_type, reference_id, notes)
      SELECT internal_product_id, 'STOCKPILE', produk_net, 'RETURN', NEW.do_id, 'Return All: ' || NEW.notes
      FROM public.delivery_order_items WHERE do_id = NEW.do_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;

grant delete on table "public"."do_cancellation_requests" to "anon";

grant insert on table "public"."do_cancellation_requests" to "anon";

grant references on table "public"."do_cancellation_requests" to "anon";

grant select on table "public"."do_cancellation_requests" to "anon";

grant trigger on table "public"."do_cancellation_requests" to "anon";

grant truncate on table "public"."do_cancellation_requests" to "anon";

grant update on table "public"."do_cancellation_requests" to "anon";

grant delete on table "public"."do_cancellation_requests" to "authenticated";

grant insert on table "public"."do_cancellation_requests" to "authenticated";

grant references on table "public"."do_cancellation_requests" to "authenticated";

grant select on table "public"."do_cancellation_requests" to "authenticated";

grant trigger on table "public"."do_cancellation_requests" to "authenticated";

grant truncate on table "public"."do_cancellation_requests" to "authenticated";

grant update on table "public"."do_cancellation_requests" to "authenticated";

grant delete on table "public"."do_cancellation_requests" to "service_role";

grant insert on table "public"."do_cancellation_requests" to "service_role";

grant references on table "public"."do_cancellation_requests" to "service_role";

grant select on table "public"."do_cancellation_requests" to "service_role";

grant trigger on table "public"."do_cancellation_requests" to "service_role";

grant truncate on table "public"."do_cancellation_requests" to "service_role";

grant update on table "public"."do_cancellation_requests" to "service_role";

CREATE TRIGGER trg_approve_do_cancellation AFTER UPDATE ON public.do_cancellation_requests FOR EACH ROW EXECUTE FUNCTION public.approve_do_cancellation();


