-- Add hex_color column to master_companies
-- Created: June 16, 2026

ALTER TABLE public.master_companies
ADD COLUMN IF NOT EXISTS hex_color text;
