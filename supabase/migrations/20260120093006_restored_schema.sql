alter table "public"."suppliers" enable row level security;


  create policy "Allow all for authenticated"
  on "public"."profiles"
  as permissive
  for all
  to public
using ((auth.role() = 'authenticated'::text));



