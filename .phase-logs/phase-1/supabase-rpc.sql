-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable trigram extension for text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create exec_raw_sql RPC for pattern queries
-- SECURITY: Only use with parameterized queries ($1, $2, etc.)
CREATE OR REPLACE FUNCTION exec_raw_sql(query text, params jsonb DEFAULT '[]'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
  param_array text[] := '{}';
  i int;
BEGIN
  -- Convert jsonb array to text array
  IF params IS NOT NULL AND jsonb_array_length(params) > 0 THEN
    FOR i IN 0..jsonb_array_length(params)-1 LOOP
      param_array := array_append(param_array, params->>i);
    END LOOP;
  END IF;

  -- Execute query with parameters
  EXECUTE query INTO result USING param_array;

  RETURN result;
END;
$$;

-- Grant execute to authenticated users (adjust based on your RLS policies)
GRANT EXECUTE ON FUNCTION exec_raw_sql TO authenticated, anon;
