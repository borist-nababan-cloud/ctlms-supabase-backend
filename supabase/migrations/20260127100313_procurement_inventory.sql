drop policy "Users can insert own profile" on "public"."user_profiles";

drop policy "Users can update own profile" on "public"."user_profiles";

drop policy "Users can view own profile" on "public"."user_profiles";

alter table "public"."shipments" drop constraint "shipments_supplier_id_fkey";


  create table "public"."delivery_orders" (
    "id" uuid not null default gen_random_uuid(),
    "created_at" timestamp with time zone default now(),
    "sales_order_id" uuid not null,
    "truck_plate" text,
    "ticket_number" text,
    "net_weight" numeric not null,
    "photo_url" text,
    "created_by" uuid
      );


alter table "public"."delivery_orders" enable row level security;


  create table "public"."inventory_ledger" (
    "id" uuid not null default gen_random_uuid(),
    "created_at" timestamp with time zone default now(),
    "product_id" uuid not null,
    "location" text default 'STOCKPILE'::text,
    "qty_change" numeric not null,
    "transaction_type" text not null,
    "reference_id" uuid,
    "notes" text
      );


alter table "public"."inventory_ledger" enable row level security;


  create table "public"."sales_orders" (
    "id" uuid not null default gen_random_uuid(),
    "created_at" timestamp with time zone default now(),
    "order_no" text not null,
    "customer_id" uuid not null,
    "product_id" uuid not null,
    "qty_ordered" numeric not null,
    "price_per_kg" numeric not null,
    "delivery_type" text,
    "status" text default 'DRAFT'::text,
    "delivery_date" date,
    "notes" text,
    "created_by" uuid
      );


alter table "public"."sales_orders" enable row level security;

alter table "public"."master_products" alter column "unit" set default 'Kg'::text;

alter table "public"."shipments" drop column "barge_name";

alter table "public"."shipments" add column "eta" date;

alter table "public"."shipments" add column "origin_location" text;

alter table "public"."shipments" add column "product_id" uuid;

alter table "public"."shipments" add column "vessel_name" text;

alter table "public"."trucking_logs" add column "created_by" uuid default auth.uid();

alter table "public"."trucking_logs" add column "updated_at" timestamp with time zone default now();

CREATE UNIQUE INDEX delivery_orders_pkey ON public.delivery_orders USING btree (id);

CREATE INDEX idx_trucking_logs_created_at ON public.trucking_logs USING btree (created_at DESC);

CREATE INDEX idx_trucking_logs_created_by ON public.trucking_logs USING btree (created_by);

CREATE INDEX idx_trucking_logs_shipment_id ON public.trucking_logs USING btree (shipment_id);

CREATE INDEX idx_user_profiles_email ON public.user_profiles USING btree (email);

CREATE INDEX idx_user_profiles_user_role ON public.user_profiles USING btree (user_role);

CREATE INDEX idx_user_profiles_uuid ON public.user_profiles USING btree (uuid);

CREATE UNIQUE INDEX inventory_ledger_pkey ON public.inventory_ledger USING btree (id);

CREATE UNIQUE INDEX sales_orders_pkey ON public.sales_orders USING btree (id);

alter table "public"."delivery_orders" add constraint "delivery_orders_pkey" PRIMARY KEY using index "delivery_orders_pkey";

alter table "public"."inventory_ledger" add constraint "inventory_ledger_pkey" PRIMARY KEY using index "inventory_ledger_pkey";

alter table "public"."sales_orders" add constraint "sales_orders_pkey" PRIMARY KEY using index "sales_orders_pkey";

alter table "public"."delivery_orders" add constraint "delivery_orders_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) not valid;

alter table "public"."delivery_orders" validate constraint "delivery_orders_created_by_fkey";

alter table "public"."delivery_orders" add constraint "delivery_orders_sales_order_id_fkey" FOREIGN KEY (sales_order_id) REFERENCES public.sales_orders(id) not valid;

alter table "public"."delivery_orders" validate constraint "delivery_orders_sales_order_id_fkey";

alter table "public"."inventory_ledger" add constraint "inventory_ledger_location_check" CHECK ((location = ANY (ARRAY['STOCKPILE'::text, 'BARGE'::text, 'CUSTOMER'::text]))) not valid;

alter table "public"."inventory_ledger" validate constraint "inventory_ledger_location_check";

alter table "public"."inventory_ledger" add constraint "inventory_ledger_product_id_fkey" FOREIGN KEY (product_id) REFERENCES public.master_products(id) not valid;

alter table "public"."inventory_ledger" validate constraint "inventory_ledger_product_id_fkey";

alter table "public"."inventory_ledger" add constraint "inventory_ledger_transaction_type_check" CHECK ((transaction_type = ANY (ARRAY['TALLY_IN'::text, 'SALES_OUT'::text, 'ADJUSTMENT'::text, 'BLENDING'::text]))) not valid;

alter table "public"."inventory_ledger" validate constraint "inventory_ledger_transaction_type_check";

alter table "public"."sales_orders" add constraint "sales_orders_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) not valid;

alter table "public"."sales_orders" validate constraint "sales_orders_created_by_fkey";

alter table "public"."sales_orders" add constraint "sales_orders_customer_id_fkey" FOREIGN KEY (customer_id) REFERENCES public.master_partners(id) not valid;

alter table "public"."sales_orders" validate constraint "sales_orders_customer_id_fkey";

alter table "public"."sales_orders" add constraint "sales_orders_delivery_type_check" CHECK ((delivery_type = ANY (ARRAY['DIRECT_BARGE'::text, 'STOCKPILE'::text, 'SCHEDULED'::text]))) not valid;

alter table "public"."sales_orders" validate constraint "sales_orders_delivery_type_check";

alter table "public"."sales_orders" add constraint "sales_orders_product_id_fkey" FOREIGN KEY (product_id) REFERENCES public.master_products(id) not valid;

alter table "public"."sales_orders" validate constraint "sales_orders_product_id_fkey";

alter table "public"."sales_orders" add constraint "sales_orders_status_check" CHECK ((status = ANY (ARRAY['DRAFT'::text, 'CONFIRMED'::text, 'COMPLETED'::text, 'CANCELLED'::text]))) not valid;

alter table "public"."sales_orders" validate constraint "sales_orders_status_check";

alter table "public"."shipments" add constraint "shipments_product_id_fkey" FOREIGN KEY (product_id) REFERENCES public.master_products(id) not valid;

alter table "public"."shipments" validate constraint "shipments_product_id_fkey";

alter table "public"."trucking_logs" add constraint "trucking_logs_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) not valid;

alter table "public"."trucking_logs" validate constraint "trucking_logs_created_by_fkey";

alter table "public"."shipments" add constraint "shipments_supplier_id_fkey" FOREIGN KEY (supplier_id) REFERENCES public.master_partners(id) not valid;

alter table "public"."shipments" validate constraint "shipments_supplier_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_new_tally_log()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  target_product_id uuid;
BEGIN
  -- Find which Product is on this Shipment
  SELECT product_id INTO target_product_id
  FROM public.shipments
  WHERE id = NEW.shipment_id;

  -- Insert into Inventory Ledger
  INSERT INTO public.inventory_ledger (
    product_id,
    location,
    qty_change,
    transaction_type,
    reference_id,
    notes
  ) VALUES (
    target_product_id,
    'STOCKPILE',
    NEW.net_weight, 
    'TALLY_IN',
    NEW.shipment_id,
    'Auto-generated from Truck ' || NEW.truck_plate
  );

  RETURN NEW;
END;
$function$
;

create or replace view "public"."view_inventory_current" as  SELECT p.id AS product_id,
    p.sku_code,
    p.name AS product_name,
    COALESCE(sum(il.qty_change), (0)::numeric) AS current_stock_kg
   FROM (public.master_products p
     LEFT JOIN public.inventory_ledger il ON ((p.id = il.product_id)))
  GROUP BY p.id, p.sku_code, p.name;


create or replace view "public"."view_shipment_summary" as  SELECT s.id AS shipment_id,
    s.reference_no,
    s.vessel_name,
    s.draft_survey_qty AS expected_qty,
    COALESCE(sum(tl.net_weight), (0)::numeric) AS total_unloaded_qty,
    (COALESCE(sum(tl.net_weight), (0)::numeric) - s.draft_survey_qty) AS variance_qty,
        CASE
            WHEN (s.draft_survey_qty = (0)::numeric) THEN (0)::numeric
            ELSE round((((COALESCE(sum(tl.net_weight), (0)::numeric) - s.draft_survey_qty) / s.draft_survey_qty) * (100)::numeric), 2)
        END AS variance_percentage
   FROM (public.shipments s
     LEFT JOIN public.trucking_logs tl ON ((s.id = tl.shipment_id)))
  GROUP BY s.id;


create or replace view "public"."view_shipments_detailed" as  SELECT s.id,
    s.reference_no,
    s.supplier_id,
    mp.name,
    mp.name AS supplier_name,
    s.product_id,
    prod.sku_code,
    prod.name AS product_name,
    s.vessel_name,
    s.origin_location AS origin_jetty,
    s.draft_survey_qty,
    s.status,
    s.eta,
    s.created_at
   FROM ((public.shipments s
     LEFT JOIN public.master_partners mp ON ((s.supplier_id = mp.id)))
     LEFT JOIN public.master_products prod ON ((s.product_id = prod.id)));


create or replace view "public"."view_trucking_summary" as  SELECT tl.id,
    tl.shipment_id,
    tl.truck_plate,
    tl.ticket_number,
    tl.gross_weight,
    tl.tare_weight,
    tl.net_weight,
    tl.photo_url,
    tl.created_at,
    s.reference_no,
    s.vessel_name
   FROM (public.trucking_logs tl
     JOIN public.shipments s ON ((tl.shipment_id = s.id)));


grant delete on table "public"."delivery_orders" to "anon";

grant insert on table "public"."delivery_orders" to "anon";

grant references on table "public"."delivery_orders" to "anon";

grant select on table "public"."delivery_orders" to "anon";

grant trigger on table "public"."delivery_orders" to "anon";

grant truncate on table "public"."delivery_orders" to "anon";

grant update on table "public"."delivery_orders" to "anon";

grant delete on table "public"."delivery_orders" to "authenticated";

grant insert on table "public"."delivery_orders" to "authenticated";

grant references on table "public"."delivery_orders" to "authenticated";

grant select on table "public"."delivery_orders" to "authenticated";

grant trigger on table "public"."delivery_orders" to "authenticated";

grant truncate on table "public"."delivery_orders" to "authenticated";

grant update on table "public"."delivery_orders" to "authenticated";

grant delete on table "public"."delivery_orders" to "postgres";

grant insert on table "public"."delivery_orders" to "postgres";

grant references on table "public"."delivery_orders" to "postgres";

grant select on table "public"."delivery_orders" to "postgres";

grant trigger on table "public"."delivery_orders" to "postgres";

grant truncate on table "public"."delivery_orders" to "postgres";

grant update on table "public"."delivery_orders" to "postgres";

grant delete on table "public"."delivery_orders" to "service_role";

grant insert on table "public"."delivery_orders" to "service_role";

grant references on table "public"."delivery_orders" to "service_role";

grant select on table "public"."delivery_orders" to "service_role";

grant trigger on table "public"."delivery_orders" to "service_role";

grant truncate on table "public"."delivery_orders" to "service_role";

grant update on table "public"."delivery_orders" to "service_role";

grant delete on table "public"."inventory_ledger" to "anon";

grant insert on table "public"."inventory_ledger" to "anon";

grant references on table "public"."inventory_ledger" to "anon";

grant select on table "public"."inventory_ledger" to "anon";

grant trigger on table "public"."inventory_ledger" to "anon";

grant truncate on table "public"."inventory_ledger" to "anon";

grant update on table "public"."inventory_ledger" to "anon";

grant delete on table "public"."inventory_ledger" to "authenticated";

grant insert on table "public"."inventory_ledger" to "authenticated";

grant references on table "public"."inventory_ledger" to "authenticated";

grant select on table "public"."inventory_ledger" to "authenticated";

grant trigger on table "public"."inventory_ledger" to "authenticated";

grant truncate on table "public"."inventory_ledger" to "authenticated";

grant update on table "public"."inventory_ledger" to "authenticated";

grant delete on table "public"."inventory_ledger" to "postgres";

grant insert on table "public"."inventory_ledger" to "postgres";

grant references on table "public"."inventory_ledger" to "postgres";

grant select on table "public"."inventory_ledger" to "postgres";

grant trigger on table "public"."inventory_ledger" to "postgres";

grant truncate on table "public"."inventory_ledger" to "postgres";

grant update on table "public"."inventory_ledger" to "postgres";

grant delete on table "public"."inventory_ledger" to "service_role";

grant insert on table "public"."inventory_ledger" to "service_role";

grant references on table "public"."inventory_ledger" to "service_role";

grant select on table "public"."inventory_ledger" to "service_role";

grant trigger on table "public"."inventory_ledger" to "service_role";

grant truncate on table "public"."inventory_ledger" to "service_role";

grant update on table "public"."inventory_ledger" to "service_role";

grant delete on table "public"."master_partners" to "postgres";

grant insert on table "public"."master_partners" to "postgres";

grant references on table "public"."master_partners" to "postgres";

grant select on table "public"."master_partners" to "postgres";

grant trigger on table "public"."master_partners" to "postgres";

grant truncate on table "public"."master_partners" to "postgres";

grant update on table "public"."master_partners" to "postgres";

grant delete on table "public"."master_products" to "postgres";

grant insert on table "public"."master_products" to "postgres";

grant references on table "public"."master_products" to "postgres";

grant select on table "public"."master_products" to "postgres";

grant trigger on table "public"."master_products" to "postgres";

grant truncate on table "public"."master_products" to "postgres";

grant update on table "public"."master_products" to "postgres";

grant delete on table "public"."master_warehouse" to "postgres";

grant insert on table "public"."master_warehouse" to "postgres";

grant references on table "public"."master_warehouse" to "postgres";

grant select on table "public"."master_warehouse" to "postgres";

grant trigger on table "public"."master_warehouse" to "postgres";

grant truncate on table "public"."master_warehouse" to "postgres";

grant update on table "public"."master_warehouse" to "postgres";

grant delete on table "public"."sales_orders" to "anon";

grant insert on table "public"."sales_orders" to "anon";

grant references on table "public"."sales_orders" to "anon";

grant select on table "public"."sales_orders" to "anon";

grant trigger on table "public"."sales_orders" to "anon";

grant truncate on table "public"."sales_orders" to "anon";

grant update on table "public"."sales_orders" to "anon";

grant delete on table "public"."sales_orders" to "authenticated";

grant insert on table "public"."sales_orders" to "authenticated";

grant references on table "public"."sales_orders" to "authenticated";

grant select on table "public"."sales_orders" to "authenticated";

grant trigger on table "public"."sales_orders" to "authenticated";

grant truncate on table "public"."sales_orders" to "authenticated";

grant update on table "public"."sales_orders" to "authenticated";

grant delete on table "public"."sales_orders" to "postgres";

grant insert on table "public"."sales_orders" to "postgres";

grant references on table "public"."sales_orders" to "postgres";

grant select on table "public"."sales_orders" to "postgres";

grant trigger on table "public"."sales_orders" to "postgres";

grant truncate on table "public"."sales_orders" to "postgres";

grant update on table "public"."sales_orders" to "postgres";

grant delete on table "public"."sales_orders" to "service_role";

grant insert on table "public"."sales_orders" to "service_role";

grant references on table "public"."sales_orders" to "service_role";

grant select on table "public"."sales_orders" to "service_role";

grant trigger on table "public"."sales_orders" to "service_role";

grant truncate on table "public"."sales_orders" to "service_role";

grant update on table "public"."sales_orders" to "service_role";

grant delete on table "public"."user_roles" to "postgres";

grant insert on table "public"."user_roles" to "postgres";

grant references on table "public"."user_roles" to "postgres";

grant select on table "public"."user_roles" to "postgres";

grant trigger on table "public"."user_roles" to "postgres";

grant truncate on table "public"."user_roles" to "postgres";

grant update on table "public"."user_roles" to "postgres";


  create policy "Enable read/write for auth users"
  on "public"."delivery_orders"
  as permissive
  for all
  to authenticated
using (true);



  create policy "Insert ledger"
  on "public"."inventory_ledger"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Read access"
  on "public"."inventory_ledger"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Read ledger"
  on "public"."inventory_ledger"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Enable read/write for auth users"
  on "public"."sales_orders"
  as permissive
  for all
  to authenticated
using (true);



  create policy "Allow insert access to authenticated users"
  on "public"."trucking_logs"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Allow read access to authenticated users"
  on "public"."trucking_logs"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Allow update own records for authenticated users"
  on "public"."trucking_logs"
  as permissive
  for update
  to authenticated
using ((auth.uid() = created_by))
with check ((auth.uid() = created_by));



  create policy "Enable insert for authenticated users"
  on "public"."trucking_logs"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Enable read for authenticated users"
  on "public"."trucking_logs"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Insert trucking logs"
  on "public"."trucking_logs"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Read trucking logs"
  on "public"."trucking_logs"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Enable insert for authenticated users"
  on "public"."user_profiles"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Enable read for authenticated users"
  on "public"."user_profiles"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Enable update own profile for authenticated users"
  on "public"."user_profiles"
  as permissive
  for update
  to authenticated
using ((auth.uid() = uuid))
with check ((auth.uid() = uuid));


CREATE TRIGGER on_tally_insert AFTER INSERT ON public.trucking_logs FOR EACH ROW EXECUTE FUNCTION public.handle_new_tally_log();


  create policy "Allow authenticated delete of tickets"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using ((bucket_id = 'tickets'::text));



  create policy "Allow authenticated update of tickets"
  on "storage"."objects"
  as permissive
  for update
  to authenticated
using ((bucket_id = 'tickets'::text))
with check ((bucket_id = 'tickets'::text));



  create policy "Allow authenticated uploads to tickets"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check ((bucket_id = 'tickets'::text));



  create policy "Allow authenticated view of tickets"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using ((bucket_id = 'tickets'::text));



