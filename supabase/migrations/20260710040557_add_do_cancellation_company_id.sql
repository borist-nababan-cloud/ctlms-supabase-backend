alter table "public"."do_cancellation_requests" add column "company_id" uuid;

alter table "public"."do_cancellation_requests" add constraint "fk_cancellation_company" FOREIGN KEY (company_id) REFERENCES public.master_companies(id) ON DELETE CASCADE not valid;

alter table "public"."do_cancellation_requests" validate constraint "fk_cancellation_company";


