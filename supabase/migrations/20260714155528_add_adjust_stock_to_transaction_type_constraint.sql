-- Add ADJUST_STOCK to inventory_ledger transaction_type CHECK constraint
-- This enables the handle_adjustment_ledger trigger to use ADJUST_STOCK type

-- Drop existing constraint
ALTER TABLE public.inventory_ledger
DROP CONSTRAINT IF EXISTS inventory_ledger_transaction_type_check;

-- Re-add with complete list including ADJUST_STOCK
ALTER TABLE public.inventory_ledger
ADD CONSTRAINT inventory_ledger_transaction_type_check
CHECK (transaction_type IN (
  'TALLY_IN',
  'SALES_OUT',
  'ADJUSTMENT',
  'PEMBELIAN',
  'SALES_STOCK_PILE',
  'TCP_INPUT',
  'RETURN',
  'SALES_LOOSING',
  'ADJUST_STOCK'
));
