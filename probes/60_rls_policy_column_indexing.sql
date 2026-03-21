-- probe: rls_policy_column_indexing
-- purpose: Detect missing indexes on columns used in RLS USING clauses.
-- prerequisites: none
-- profiles: default, performance, supabase_default
-- note: Supabase-specific. RLS is enabled by default; missing indexes on
--        policy columns cause sequential scans on every API request.

WITH rls_tables AS (
  SELECT
    c.oid AS relid,
    n.nspname AS schemaname,
    c.relname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relrowsecurity = true
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
),
policy_columns AS (
  SELECT DISTINCT
    rt.schemaname,
    rt.relname,
    rt.relid,
    a.attname AS column_name
  FROM rls_tables rt
  JOIN pg_policy p ON p.polrelid = rt.relid
  JOIN pg_depend d ON d.objid = p.oid
  JOIN pg_attribute a ON a.attrelid = rt.relid AND a.attnum = d.refobjsubid
  WHERE d.classid = 'pg_policy'::regclass
    AND d.refclassid = 'pg_class'::regclass
    AND a.attnum > 0
    AND NOT a.attisdropped

  UNION

  -- Fallback: extract column references from policy qual text
  SELECT DISTINCT
    rt.schemaname,
    rt.relname,
    rt.relid,
    a.attname AS column_name
  FROM rls_tables rt
  JOIN pg_policy p ON p.polrelid = rt.relid
  JOIN pg_attribute a ON a.attrelid = rt.relid
    AND a.attnum > 0
    AND NOT a.attisdropped
  WHERE pg_get_expr(p.polqual, p.polrelid) LIKE '%' || a.attname || '%'
     OR pg_get_expr(p.polwithcheck, p.polrelid) LIKE '%' || a.attname || '%'
),
indexed_columns AS (
  SELECT
    indrelid,
    unnest(string_to_array(
      array_to_string(indkey::int[], ','), ','
    ))::smallint AS attnum
  FROM pg_index
)
SELECT
  pc.schemaname,
  pc.relname AS tablename,
  pc.column_name,
  CASE
    WHEN ic.attnum IS NOT NULL THEN true
    ELSE false
  END AS has_index
FROM policy_columns pc
LEFT JOIN indexed_columns ic
  ON ic.indrelid = pc.relid
  AND ic.attnum = (
    SELECT a2.attnum
    FROM pg_attribute a2
    WHERE a2.attrelid = pc.relid
      AND a2.attname = pc.column_name
      AND a2.attnum > 0
      AND NOT a2.attisdropped
    LIMIT 1
  )
ORDER BY pc.schemaname, pc.relname, pc.column_name;
