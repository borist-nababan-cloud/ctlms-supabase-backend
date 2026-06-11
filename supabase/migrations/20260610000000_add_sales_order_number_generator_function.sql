-- Migration: Add Sales Order Number Generator Function
-- Created: June 10, 2026
-- Description: Creates get_next_so_number() function for auto-generating sequential SO numbers in format SO/YYMM/XXXXX (sequence resets yearly, not monthly)

CREATE OR REPLACE FUNCTION public.get_next_so_number()
RETURNS text AS $$
DECLARE
  v_curr_y text := to_char(now(), 'YY');
  v_curr_ym text := to_char(now(), 'YYMM');
  v_year_prefix text := 'SO/' || v_curr_y || '/';
  v_display_prefix text := 'SO/' || v_curr_ym || '/';
  v_last_seq int;
  v_new_seq int;
BEGIN
  -- Ambil nomor urut terakhir untuk tahun ini (sequence resets yearly)
  SELECT COALESCE(MAX(NULLIF(regexp_replace(order_no, '^SO/\d{2}/', ''), '')::integer), 0)
  INTO v_last_seq
  FROM public.sales_orders
  WHERE order_no LIKE v_year_prefix || '%';

  v_new_seq := v_last_seq + 1;

  -- Return format SO/YYMM/XXXXX (shows month, but sequence continues across months)
  RETURN v_display_prefix || LPAD(v_new_seq::text, 5, '0');
END;
$$ LANGUAGE plpgsql;
