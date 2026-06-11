-- Add shipment_id and vessel_name columns to delivery_order_items
-- This allows tracking which shipment/vessel each delivery item came from

alter table "public"."delivery_order_items" add column if not exists "shipment_id" uuid;

alter table "public"."delivery_order_items" add column if not exists "vessel_name" text;

alter table "public"."delivery_order_items" add constraint "delivery_order_items_shipment_id_fkey" FOREIGN KEY (shipment_id) REFERENCES public.shipments(id) on delete set null on update cascade;
