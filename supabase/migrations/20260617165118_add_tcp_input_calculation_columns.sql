-- Add calculation columns to tcp_input for permanent storage
ALTER TABLE "public"."tcp_input" ADD COLUMN "actual_stock_system" numeric default 0;

ALTER TABLE "public"."tcp_input" ADD COLUMN "selisih" numeric default 0;
