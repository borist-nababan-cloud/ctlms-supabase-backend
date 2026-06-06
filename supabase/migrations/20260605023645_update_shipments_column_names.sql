drop view if exists "public"."view_shipment_summary";

drop view if exists "public"."view_shipments_detailed";

drop view if exists "public"."view_trucking_summary";

-- Add new column jenis_batu
alter table "public"."shipments" add column "jenis_batu" text;

alter table "public"."shipments" add constraint "shipments_jenis_batu_check" CHECK ((jenis_batu = ANY (ARRAY['High'::text, 'Medium'::text, 'Low'::text]))) not valid;

alter table "public"."shipments" validate constraint "shipments_jenis_batu_check";

-- Rename columns to preserve existing data
alter table "public"."shipments" rename column "reference_no" to "invoice_no";

alter table "public"."shipments" rename column "origin_location" to "asal_batu";

alter table "public"."shipments" rename column "draft_survey_qty" to "quantity";

create or replace view "public"."view_shipment_summary" as  SELECT s.id AS shipment_id,
    s.invoice_no,
    s.vessel_name,
    s.quantity AS expected_qty,
    COALESCE(sum(tl.net_weight), (0)::numeric) AS total_unloaded_qty,
    s.is_completed,
        CASE
            WHEN (s.quantity = (0)::numeric) THEN (0)::numeric
            ELSE round((((COALESCE(sum(tl.net_weight), (0)::numeric) - s.quantity) / s.quantity) * (100)::numeric), 2)
        END AS variance_percentage
   FROM (public.shipments s
     LEFT JOIN public.trucking_logs tl ON ((s.id = tl.shipment_id)))
  GROUP BY s.id;


create or replace view "public"."view_shipments_detailed" as  SELECT s.id,
    s.invoice_no,
    s.supplier_id,
    s.quantity,
    s.status,
    s.created_by,
    s.created_at,
    s.eta,
    s.asal_batu,
    s.product_id,
    s.vessel_name,
    s.company_id,
    s.issue_date,
    s.loading_date,
    s.qty_loading,
    s.harga,
    s.ppn_tax,
    s.pph_tax,
    s.disc,
    s.is_completed,
    s.jenis_batu,
    mp.name AS supplier_name,
    prod.name AS product_name,
    prod.sku_code,
    mc.name AS company_name
   FROM (((public.shipments s
     LEFT JOIN public.master_partners mp ON ((s.supplier_id = mp.id)))
     LEFT JOIN public.master_products prod ON ((s.product_id = prod.id)))
     LEFT JOIN public.master_companies mc ON ((s.company_id = mc.id)));


create or replace view "public"."view_trucking_summary" as  SELECT tl.id,
    tl.shipment_id,
    tl.truck_plate,
    tl.ticket_number,
    tl.gross_weight,
    tl.tare_weight,
    tl.net_weight,
    tl.photo_url,
    tl.created_at,
    s.invoice_no AS reference_no,
    s.vessel_name
   FROM (public.trucking_logs tl
     JOIN public.shipments s ON ((tl.shipment_id = s.id)));



