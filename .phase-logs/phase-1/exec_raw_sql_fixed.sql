-- Fixed exec_raw_sql RPC that returns query results as JSONB array
-- Replace the existing function with this version

CREATE OR REPLACE FUNCTION exec_raw_sql(query text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  -- Execute query and convert results to JSONB array
  EXECUTE format('SELECT jsonb_agg(row_to_json(t)) FROM (%s) t', query) INTO result;

  -- Return empty array if no results
  RETURN COALESCE(result, '[]'::jsonb);
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Query execution failed: %', SQLERRM;
END;
$$;

GRANT EXECUTE ON FUNCTION exec_raw_sql TO authenticated, anon;
