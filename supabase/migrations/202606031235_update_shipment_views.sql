-- Migration: Update shipment views with company support
-- This recreates the shipment views to include company information

-- 1. DROP old views
DROP VIEW IF EXISTS public.view_shipments_detailed;
DROP VIEW IF EXISTS public.view_shipment_summary;

-- 2. CREATE VIEW view_shipments_detailed (Detail Pengiriman)
CREATE OR REPLACE VIEW public.view_shipments_detailed AS
SELECT
    s.*,
    mp.name as supplier_name,
    prod.name as product_name,
    prod.sku_code,
    mc.name as company_name
FROM public.shipments s
LEFT JOIN public.master_partners mp ON s.supplier_id = mp.id
LEFT JOIN public.master_products prod ON s.product_id = prod.id
LEFT JOIN public.master_companies mc ON s.company_id = mc.id;

-- 3. CREATE VIEW view_shipment_summary (Ringkasan Logistik)
CREATE OR REPLACE VIEW public.view_shipment_summary AS
SELECT
  s.id as shipment_id,
  s.reference_no,
  s.vessel_name,
  s.draft_survey_qty as expected_qty,
  COALESCE(SUM(tl.net_weight), 0) as total_unloaded_qty,
  s.is_completed,
  CASE
    WHEN s.draft_survey_qty = 0 THEN 0
    ELSE ROUND(((COALESCE(SUM(tl.net_weight), 0) - s.draft_survey_qty) / s.draft_survey_qty * 100), 2)
  END as variance_percentage
FROM public.shipments s
LEFT JOIN public.trucking_logs tl ON s.id = tl.shipment_id
GROUP BY s.id;

-- Add comments
COMMENT ON VIEW public.view_shipments_detailed IS 'Detailed shipment information with supplier, product, and company details';
COMMENT ON VIEW public.view_shipment_summary IS 'Shipment summary with actual unloaded quantities and variance calculations';
