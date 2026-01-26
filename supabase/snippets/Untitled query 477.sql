-- Add Foreign Key Constraint
ALTER TABLE public.user_profiles
ADD CONSTRAINT user_profiles_user_role_fkey
FOREIGN KEY (user_role)
REFERENCES public.user_roles (id)
ON DELETE SET NULL;