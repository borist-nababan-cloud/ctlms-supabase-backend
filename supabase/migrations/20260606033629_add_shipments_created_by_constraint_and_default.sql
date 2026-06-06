alter table "public"."shipments" alter column "created_by" set default auth.uid();

alter table "public"."shipments" add constraint "shipments_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."shipments" validate constraint "shipments_created_by_fkey";


