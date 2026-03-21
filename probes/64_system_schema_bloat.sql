-- probe: system_schema_bloat
-- purpose: Detect vacuum/maintenance pressure across all Supabase system schemas.
-- prerequisites: none
-- profiles: default, reliability
-- note: Supabase-specific. System schemas need vacuum like any other tables.

SELECT
  schemaname,
  relname,
  n_live_tup,
  n_dead_tup,
  ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_tuple_pct,
  last_autovacuum,
  last_autoanalyze,
  pg_total_relation_size(relid) AS total_bytes
FROM pg_stat_user_tables
WHERE schemaname IN ('auth', 'storage', 'realtime', 'extensions', 'supabase_functions')
ORDER BY n_dead_tup DESC
LIMIT 30;
