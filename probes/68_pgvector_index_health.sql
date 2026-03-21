-- probe: pgvector_index_health
-- purpose: Assess vector index configuration and health.
-- prerequisites: pgvector extension
-- profiles: default, performance
-- note: Supabase-specific. Missing vector indexes cause sequential distance scans.

WITH vector_columns AS (
  SELECT
    n.nspname AS schemaname,
    c.relname AS table_name,
    c.oid AS relid,
    a.attname AS column_name,
    format_type(a.atttypid, a.atttypmod) AS column_type
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE a.atttypid IN (
    SELECT t.oid FROM pg_type t WHERE t.typname IN ('vector', 'halfvec', 'sparsevec')
  )
    AND a.attnum > 0
    AND NOT a.attisdropped
    AND c.relkind = 'r'
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
),
vector_indexes AS (
  SELECT
    i.indrelid,
    ic.relname AS index_name,
    am.amname AS index_type,
    pg_relation_size(ic.oid) AS index_bytes,
    pg_get_indexdef(i.indexrelid) AS index_def
  FROM pg_index i
  JOIN pg_class ic ON ic.oid = i.indexrelid
  JOIN pg_am am ON am.oid = ic.relam
  WHERE am.amname IN ('ivfflat', 'hnsw')
)
SELECT
  vc.schemaname,
  vc.table_name,
  vc.column_name,
  vc.column_type,
  (SELECT n_live_tup FROM pg_stat_user_tables s WHERE s.relid = vc.relid) AS row_count,
  vi.index_name,
  vi.index_type,
  vi.index_bytes,
  vi.index_def,
  CASE WHEN vi.index_name IS NULL THEN true ELSE false END AS missing_vector_index
FROM vector_columns vc
LEFT JOIN vector_indexes vi ON vi.indrelid = vc.relid
ORDER BY vc.schemaname, vc.table_name, vc.column_name;
