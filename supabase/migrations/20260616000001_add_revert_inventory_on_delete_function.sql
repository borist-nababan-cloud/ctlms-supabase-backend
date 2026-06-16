-- Create revert_inventory_on_delete function
-- This function reverses inventory when a delivery_order_item is deleted
-- Created: June 16, 2026

CREATE OR REPLACE FUNCTION public.revert_inventory_on_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- Hanya jalankan insert ke ledger jika product_id ada
  -- Jika tidak ada, kita lewati saja agar proses DELETE tetap sukses
  IF OLD.internal_product_id IS NOT NULL THEN

    INSERT INTO public.inventory_ledger (
      product_id,
      location,
      qty_change,
      transaction_type,
      reference_id,
      company_id,
      notes
    ) VALUES (
      OLD.internal_product_id,
      'STOCKPILE',
      OLD.net_weight,
      'ADJUSTMENT', -- Kita gunakan ADJUSTMENT untuk membalikkan stok
      OLD.do_id,
      (SELECT company_id FROM public.delivery_orders WHERE id = OLD.do_id),
      'REVERSAL: Deleted Item Truck ' || OLD.truck_plate
    );

  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
