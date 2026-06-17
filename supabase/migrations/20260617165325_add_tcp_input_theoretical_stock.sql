-- Add theoretical_stock column to tcp_input for calculation storage
ALTER TABLE "public"."tcp_input" ADD COLUMN "theoretical_stock" numeric default 0;
