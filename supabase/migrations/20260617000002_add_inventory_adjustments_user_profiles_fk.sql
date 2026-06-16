-- Migration: Add foreign key constraints between inventory_adjustments and user_profiles
-- Created: June 17, 2026
-- Description: Adds foreign keys to allow PostgREST to automatically resolve joins between inventory_adjustments and user_profiles for both created_by and approved_by fields.

ALTER TABLE public.inventory_adjustments
  DROP CONSTRAINT IF EXISTS inventory_adjustments_created_by_user_profiles_fkey,
  ADD CONSTRAINT inventory_adjustments_created_by_user_profiles_fkey
  FOREIGN KEY (created_by) REFERENCES public.user_profiles(uuid)
  ON DELETE SET NULL;

ALTER TABLE public.inventory_adjustments
  DROP CONSTRAINT IF EXISTS inventory_adjustments_approved_by_user_profiles_fkey,
  ADD CONSTRAINT inventory_adjustments_approved_by_user_profiles_fkey
  FOREIGN KEY (approved_by) REFERENCES public.user_profiles(uuid)
  ON DELETE SET NULL;
