-- Migration: Update generate_sj_number to return pure 5-digit number (no prefix)
-- Format change: SJ/YYMM/XXXXX -> XXXXX (pure 5-digit sequence number)
-- Created: 2026-07-21

CREATE OR REPLACE FUNCTION public.generate_sj_number(p_company_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_last_seq int;
  v_new_seq int;
BEGIN
  -- Pastikan record counter ada untuk perusahaan tersebut
  INSERT INTO public.do_sequences (company_id, last_number)
  VALUES (p_company_id, 0)
  ON CONFLICT (company_id) DO NOTHING;

  -- Kunci baris untuk menghindari duplikasi
  SELECT last_number INTO v_last_seq
  FROM public.do_sequences
  WHERE company_id = p_company_id
  FOR UPDATE;

  v_new_seq := v_last_seq + 1;

  -- Update counter
  UPDATE public.do_sequences SET last_number = v_new_seq WHERE company_id = p_company_id;

  -- Return format 5 DIGIT MURNI (misal: 03542 atau 35420)
  RETURN LPAD(v_new_seq::text, 5, '0');
END;
$$;

-- Refresh API
NOTIFY pgrst, 'reload config';
