-- Update delivery_orders created_by FK to reference user_profiles instead of auth.users
-- Created: July 23, 2026

-- 1. Drop old constraint if it points to auth.users
DO $$
BEGIN
  EXECUTE (
    SELECT 'ALTER TABLE public.delivery_orders DROP CONSTRAINT ' || quote_ident(conname)
    FROM pg_constraint
    WHERE conrelid = 'public.delivery_orders'::regclass
    AND confrelid = 'auth.users'::regclass
  );
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 2. Add new foreign key to user_profiles
ALTER TABLE public.delivery_orders
ADD CONSTRAINT fk_delivery_orders_created_by
FOREIGN KEY (created_by) REFERENCES public.user_profiles(uuid)
ON DELETE SET NULL;

-- 3. Grant SELECT permission on user_profiles
GRANT SELECT ON public.user_profiles TO authenticated;

-- 4. Reload API config
NOTIFY pgrst, 'reload config';
