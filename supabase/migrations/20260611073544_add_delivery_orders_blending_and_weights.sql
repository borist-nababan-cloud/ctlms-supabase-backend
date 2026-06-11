-- Add blending support and weight columns to delivery_orders header
-- This allows tracking blending operations and summary weights

-- Add blending support columns
alter table "public"."delivery_orders" add column if not exists "is_blending" boolean default false;
alter table "public"."delivery_orders" add column if not exists "blending_id" uuid;

-- Add foreign key constraint for blending_id
alter table "public"."delivery_orders" add constraint "delivery_orders_blending_id_fkey"
  FOREIGN KEY (blending_id) REFERENCES public.master_blending(id) ON DELETE SET NULL ON UPDATE CASCADE;

-- Create index for blending lookups
CREATE INDEX IF NOT EXISTS idx_do_blending_id ON public.delivery_orders(blending_id);

-- Note: Weight columns (truck_plate, ticket_number, gross_weight, tare_weight, net_weight)
-- already exist in the table from previous migrations and are not included here.
