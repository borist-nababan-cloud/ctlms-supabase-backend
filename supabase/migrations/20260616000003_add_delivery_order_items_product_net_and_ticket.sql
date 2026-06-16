-- Add product_net, produk_net, and ticket_number columns to delivery_order_items
-- Created: June 16, 2026

-- Add product_net column
ALTER TABLE public.delivery_order_items
ADD COLUMN IF NOT EXISTS product_net numeric DEFAULT '0';

-- Add produk_net column
ALTER TABLE public.delivery_order_items
ADD COLUMN IF NOT EXISTS produk_net numeric DEFAULT 0;

-- Add ticket_number column
ALTER TABLE public.delivery_order_items
ADD COLUMN IF NOT EXISTS ticket_number text;
