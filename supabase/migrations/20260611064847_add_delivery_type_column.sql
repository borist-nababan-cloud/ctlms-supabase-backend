-- Add delivery_type column to delivery_orders
-- Values: 'DIRECT' (direct to barge/vessel) or 'STOCKPILE' (to warehouse stockpile)

-- Add the column
alter table "public"."delivery_orders" add column if not exists "delivery_type" text;

-- Add check constraint
alter table "public"."delivery_orders" add constraint "delivery_orders_delivery_type_check"
  CHECK (delivery_type IN ('DIRECT', 'STOCKPILE'));

-- Migrate existing data
-- Records with shipment_id are considered DIRECT delivery
UPDATE public.delivery_orders
SET delivery_type = 'DIRECT'
WHERE shipment_id IS NOT NULL AND delivery_type IS NULL;

-- Records without shipment_id are considered STOCKPILE
UPDATE public.delivery_orders
SET delivery_type = 'STOCKPILE'
WHERE delivery_type IS NULL;
