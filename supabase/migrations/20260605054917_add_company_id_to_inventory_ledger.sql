alter table "public"."inventory_ledger" add column "company_id" uuid;

alter table "public"."inventory_ledger" add constraint "inventory_ledger_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.master_companies(id) not valid;

alter table "public"."inventory_ledger" validate constraint "inventory_ledger_company_id_fkey";


