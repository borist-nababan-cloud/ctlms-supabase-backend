-- Update delivery_order_items foreign key constraint with proper cascade behavior
-- This ensures referential integrity when shipments are deleted or updated

-- Drop existing constraint
alter table "public"."delivery_order_items" drop constraint if exists "delivery_order_items_shipment_id_fkey";

-- Add constraint with cascade behavior
alter table "public"."delivery_order_items" add constraint "delivery_order_items_shipment_id_fkey"
  FOREIGN KEY (shipment_id) REFERENCES public.shipments(id)
  ON DELETE SET NULL
  ON UPDATE CASCADE;
