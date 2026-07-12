alter table "public"."do_cancellation_requests" drop constraint "do_cancellation_requests_approved_by_fkey";

alter table "public"."do_cancellation_requests" drop constraint "do_cancellation_requests_created_by_fkey";

alter table "public"."do_cancellation_requests" add constraint "fk_cancellation_approved_by" FOREIGN KEY (approved_by) REFERENCES public.user_profiles(uuid) ON DELETE SET NULL not valid;

alter table "public"."do_cancellation_requests" validate constraint "fk_cancellation_approved_by";

alter table "public"."do_cancellation_requests" add constraint "fk_cancellation_created_by" FOREIGN KEY (created_by) REFERENCES public.user_profiles(uuid) ON DELETE SET NULL not valid;

alter table "public"."do_cancellation_requests" validate constraint "fk_cancellation_created_by";


