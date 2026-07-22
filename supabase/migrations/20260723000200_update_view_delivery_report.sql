-- Update view_delivery_report with company_id and corrected qty_kg from detail table
-- Created: July 23, 2026

-- 1. Hapus secara paksa (agar tidak ada caching view lama)
DROP VIEW IF EXISTS public.view_delivery_report CASCADE;

-- 2. Buat ulang View dengan kolom lengkap
CREATE VIEW public.view_delivery_report AS
SELECT
  d_ord.id,
  d_ord.company_id,
  d_ord.is_cancel,
  d_ord.created_at,
  so.order_no,
  so.po_number,
  d_ord.sj_number,
  d_ord.delivery_type,
  mp.name as customer_name,
  so.product_name as published_product,
  prod.name as internal_product_name,
  doi.produk_net as qty_kg,
  d_ord.type_blending,
  mtp.nama_type as type_production,
  tp.name as transporter_name,
  doi.truck_plate
FROM public.delivery_orders d_ord
JOIN public.sales_orders so ON d_ord.sales_order_id = so.id
JOIN public.delivery_order_items doi ON d_ord.id = doi.do_id
JOIN public.master_partners mp ON so.customer_id = mp.id
JOIN public.master_products prod ON doi.internal_product_id = prod.id
LEFT JOIN public.master_type_production mtp ON doi.type_production_id = mtp.id
LEFT JOIN public.master_partners tp ON d_ord.transporter_id = tp.id;

-- 3. Berikan izin akses
GRANT SELECT ON public.view_delivery_report TO authenticated;

-- 4. Paksa API reload skema
NOTIFY pgrst, 'reload config';
