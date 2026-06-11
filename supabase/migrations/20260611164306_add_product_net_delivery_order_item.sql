alter table "public"."delivery_orders" drop constraint "delivery_orders_blending_id_fkey";

alter table "public"."delivery_order_items" add column "product_net" numeric default '0'::numeric;

alter table "public"."delivery_orders" add constraint "delivery_orders_blending_id_fkey" FOREIGN KEY (blending_id) REFERENCES public.master_blending(id) not valid;

alter table "public"."delivery_orders" validate constraint "delivery_orders_blending_id_fkey";


