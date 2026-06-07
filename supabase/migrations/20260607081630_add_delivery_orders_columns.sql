alter table "public"."delivery_orders" add column "company_id" uuid;

alter table "public"."delivery_orders" add column "date_of_issue" date default CURRENT_DATE;

alter table "public"."delivery_orders" add column "gross_terima" numeric default 0;

alter table "public"."delivery_orders" add column "gross_weight" numeric default 0;

alter table "public"."delivery_orders" add column "net_terima" numeric default 0;

alter table "public"."delivery_orders" add column "shipment_id" uuid;

alter table "public"."delivery_orders" add column "sj_number" text;

alter table "public"."delivery_orders" add column "tare_terima" numeric default 0;

alter table "public"."delivery_orders" add column "tare_weight" numeric default 0;

alter table "public"."delivery_orders" add column "vessel_name" text;

alter table "public"."delivery_orders" add constraint "delivery_orders_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.master_companies(id) not valid;

alter table "public"."delivery_orders" validate constraint "delivery_orders_company_id_fkey";

alter table "public"."delivery_orders" add constraint "delivery_orders_shipment_id_fkey" FOREIGN KEY (shipment_id) REFERENCES public.shipments(id) not valid;

alter table "public"."delivery_orders" validate constraint "delivery_orders_shipment_id_fkey";


