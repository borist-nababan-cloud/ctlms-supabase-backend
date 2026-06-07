
  create table "public"."do_sequences" (
    "company_id" uuid not null,
    "last_number" integer default 0
      );


CREATE UNIQUE INDEX do_sequences_pkey ON public.do_sequences USING btree (company_id);

alter table "public"."do_sequences" add constraint "do_sequences_pkey" PRIMARY KEY using index "do_sequences_pkey";

alter table "public"."do_sequences" add constraint "do_sequences_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.master_companies(id) not valid;

alter table "public"."do_sequences" validate constraint "do_sequences_company_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.generate_sj_number(p_company_id uuid)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_last_number integer;
  v_new_number integer;
  v_company_prefix text;
BEGIN
  -- Ambil dan kunci baris counter
  INSERT INTO public.do_sequences (company_id, last_number)
  VALUES (p_company_id, 0)
  ON CONFLICT (company_id) DO NOTHING;

  SELECT last_number + 1 INTO v_new_number
  FROM public.do_sequences
  WHERE company_id = p_company_id
  FOR UPDATE;

  -- Update counter
  UPDATE public.do_sequences SET last_number = v_new_number WHERE company_id = p_company_id;

  -- Format: 0001
  RETURN LPAD(v_new_number::text, 4, '0');
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_do_inventory()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.inventory_ledger (
    product_id, location, qty_change, transaction_type, reference_id, company_id, notes
  ) VALUES (
    (SELECT product_id FROM public.master_sales_order WHERE id = NEW.sales_order_id),
    'STOCKPILE',
    -NEW.net_weight, -- Mengurangi stok
    'SALES_OUT',
    NEW.id,
    NEW.company_id,
    'DO No: ' || NEW.sj_number
  );
  RETURN NEW;
END;
$function$
;

grant delete on table "public"."do_sequences" to "anon";

grant insert on table "public"."do_sequences" to "anon";

grant references on table "public"."do_sequences" to "anon";

grant select on table "public"."do_sequences" to "anon";

grant trigger on table "public"."do_sequences" to "anon";

grant truncate on table "public"."do_sequences" to "anon";

grant update on table "public"."do_sequences" to "anon";

grant delete on table "public"."do_sequences" to "authenticated";

grant insert on table "public"."do_sequences" to "authenticated";

grant references on table "public"."do_sequences" to "authenticated";

grant select on table "public"."do_sequences" to "authenticated";

grant trigger on table "public"."do_sequences" to "authenticated";

grant truncate on table "public"."do_sequences" to "authenticated";

grant update on table "public"."do_sequences" to "authenticated";

grant delete on table "public"."do_sequences" to "service_role";

grant insert on table "public"."do_sequences" to "service_role";

grant references on table "public"."do_sequences" to "service_role";

grant select on table "public"."do_sequences" to "service_role";

grant trigger on table "public"."do_sequences" to "service_role";

grant truncate on table "public"."do_sequences" to "service_role";

grant update on table "public"."do_sequences" to "service_role";

CREATE TRIGGER trg_do_inventory AFTER INSERT ON public.delivery_orders FOR EACH ROW EXECUTE FUNCTION public.handle_do_inventory();


