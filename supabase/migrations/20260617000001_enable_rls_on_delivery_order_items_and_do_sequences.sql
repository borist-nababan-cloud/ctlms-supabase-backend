-- Migration: Enable RLS on delivery_order_items and do_sequences
-- Created: June 17, 2026
-- Description: Enables Row Level Security on delivery orders related tables

-- Enable RLS
ALTER TABLE public.delivery_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.do_sequences ENABLE ROW LEVEL SECURITY;

-- RLS Policies for delivery_order_items
CREATE POLICY "Authenticated users can view delivery order items" ON public.delivery_order_items
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert delivery order items" ON public.delivery_order_items
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update delivery order items" ON public.delivery_order_items
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete delivery order items" ON public.delivery_order_items
  FOR DELETE USING (auth.role() = 'authenticated');

-- RLS Policies for do_sequences
CREATE POLICY "Authenticated users can view do sequences" ON public.do_sequences
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert do sequences" ON public.do_sequences
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update do sequences" ON public.do_sequences
  FOR UPDATE USING (auth.role() = 'authenticated');
