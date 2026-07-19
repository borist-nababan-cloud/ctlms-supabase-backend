-- Update request_type CHECK constraint on do_cancellation_requests
--
-- Removes old constraint and adds clean version with only valid request types:
-- - 'Ganti Kendaraan' (Change Truck)
-- - 'Ganti Sales Order' (Change Sales Order)
-- - 'Pengembalian Stok (Total)' (Return Total)

-- 1. Hapus constraint lama
ALTER TABLE public.do_cancellation_requests
DROP CONSTRAINT IF EXISTS do_cancellation_requests_request_type_check;

-- 2. Tambahkan constraint baru yang bersih (Hanya pilihan yang valid)
ALTER TABLE public.do_cancellation_requests
ADD CONSTRAINT do_cancellation_requests_request_type_check
CHECK (request_type IN (
  'Ganti Kendaraan',
  'Ganti Sales Order',
  'Pengembalian Stok (Total)'
));
