drop policy "Enable read for authenticated users" on "public"."user_profiles";

drop policy "Enable update own profile for authenticated users" on "public"."user_profiles";

alter table "public"."master_companies" add column "logo_url" text;

alter table "public"."master_companies" enable row level security;

alter table "public"."master_warehouse" add column "company_id" uuid;

alter table "public"."user_profiles" add column "company_id" uuid;

CREATE INDEX idx_user_company ON public.user_profiles USING btree (company_id);

CREATE INDEX idx_warehouse_company ON public.master_warehouse USING btree (company_id);

alter table "public"."master_warehouse" add constraint "master_warehouse_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.master_companies(id) not valid;

alter table "public"."master_warehouse" validate constraint "master_warehouse_company_id_fkey";

alter table "public"."user_profiles" add constraint "user_profiles_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.master_companies(id) not valid;

alter table "public"."user_profiles" validate constraint "user_profiles_company_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.is_superuser(user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE uuid = user_id AND (user_role = 8 OR user_role = 1)
  );
END;
$function$
;


  create policy "Enable insert access for authenticated users"
  on "public"."master_companies"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Enable read access for authenticated users"
  on "public"."master_companies"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Enable update access for authenticated users"
  on "public"."master_companies"
  as permissive
  for update
  to authenticated
using (true);



  create policy "Enable insert access for authenticated users"
  on "public"."master_warehouse"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Enable read access for authenticated users"
  on "public"."master_warehouse"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Enable update access for authenticated users"
  on "public"."master_warehouse"
  as permissive
  for update
  to authenticated
using (true);



  create policy "Allow select for own profile or superusers"
  on "public"."user_profiles"
  as permissive
  for select
  to authenticated
using (((auth.uid() = uuid) OR public.is_superuser(auth.uid())));



  create policy "Allow update for superusers only"
  on "public"."user_profiles"
  as permissive
  for update
  to authenticated
using (public.is_superuser(auth.uid()))
with check (public.is_superuser(auth.uid()));



  create policy "Enable insert access for authenticated users"
  on "public"."user_roles"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Enable read access for authenticated users"
  on "public"."user_roles"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Enable update access for authenticated users"
  on "public"."user_roles"
  as permissive
  for update
  to authenticated
using (true);



  create policy "Authenticated Upload Access"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check ((bucket_id = 'company-logos'::text));



  create policy "Public Read Access"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'company-logos'::text));



