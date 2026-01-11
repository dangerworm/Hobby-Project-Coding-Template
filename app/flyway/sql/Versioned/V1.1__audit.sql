CREATE TABLE IF NOT EXISTS public.audit (
  id SERIAL PRIMARY KEY,
  updated_at TIMESTAMP DEFAULT NOW(),
  operation TEXT NOT NULL,
  table_name TEXT NOT NULL,
  previous_value TEXT,
  new_value TEXT
);

CREATE OR REPLACE FUNCTION public.audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit (table_name, operation, new_value)
    VALUES (TG_TABLE_NAME, TG_OP, row_to_json(NEW));

  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.audit (table_name, operation, previous_value, new_value)
    VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD), row_to_json(NEW));

  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.audit (table_name, operation, previous_value)
    VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD));
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
