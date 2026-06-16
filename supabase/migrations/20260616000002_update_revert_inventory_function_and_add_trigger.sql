-- Create revert_inventory_on_delete function and trigger
-- This function reverses inventory when a delivery_order_item is deleted
-- Created: June 16, 2026

-- 1. Buat Fungsi Pembalik (Reversal)
CREATE OR REPLACE FUNCTION public.revert_inventory_on_delete()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id uuid;
BEGIN
  -- Ambil company_id dari Header (delivery_orders)
  -- untuk memastikan ledger memiliki data company yang benar
  SELECT company_id INTO v_company_id FROM public.delivery_orders WHERE id = OLD.do_id;

  -- Insert ledger baru dengan qty positif (menambah stok kembali)
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
    OLD.produk_net, -- Mengembalikan stok sejumlah produk_net yang dihapus
    'ADJUSTMENT',
    OLD.do_id,
    v_company_id,
    'REVERSAL: Deleted Item Truck ' || OLD.truck_plate
  );

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Hapus trigger lama jika ada, lalu pasang yang baru
DROP TRIGGER IF EXISTS trg_revert_inventory_on_delete ON public.delivery_order_items;

CREATE TRIGGER trg_revert_inventory_on_delete
AFTER DELETE ON public.delivery_order_items
FOR EACH ROW
EXECUTE FUNCTION public.revert_inventory_on_delete();
