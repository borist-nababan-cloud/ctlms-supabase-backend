-- Migration: Add rejection_notes and TCP status sync
-- Created: June 17, 2026
-- Description: Adds rejection_notes to inventory_adjustments and tcp_input, adds status to tcp_input, and creates sync trigger

-- Add rejection_notes to inventory_adjustments
ALTER TABLE public.inventory_adjustments
ADD COLUMN IF NOT EXISTS rejection_notes text;

-- Add rejection_notes to tcp_input
ALTER TABLE public.tcp_input
ADD COLUMN IF NOT EXISTS rejection_notes text;

-- Add status column to tcp_input with CHECK constraint
ALTER TABLE public.tcp_input
ADD COLUMN IF NOT EXISTS status text DEFAULT 'ON_REQUEST';

ALTER TABLE public.tcp_input
ADD CONSTRAINT tcp_input_status_check
CHECK (status IN ('ON_REQUEST', 'APPROVED', 'REJECTED'));

-- Function to sync TCP status from inventory_adjustments
CREATE OR REPLACE FUNCTION public.sync_tcp_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.tcp_input
  SET
    status = NEW.status,
    rejection_notes = NEW.rejection_notes
  WHERE inventory_adjustment_id = NEW.id;

  RETURN NEW;
END;
$function$;

-- Trigger to sync status when inventory_adjustments is updated
CREATE TRIGGER trg_sync_tcp_status
AFTER UPDATE ON public.inventory_adjustments
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.rejection_notes IS DISTINCT FROM NEW.rejection_notes)
EXECUTE FUNCTION public.sync_tcp_status();
