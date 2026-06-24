-- Add company_id column to master_products with nullable foreign key to master_companies
ALTER TABLE public.master_products
ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.master_companies(id) ON DELETE SET NULL;

-- Add comment for documentation
COMMENT ON COLUMN public.master_products.company_id IS 'Optional reference to master_companies. Nullable - product may not belong to a company.';
