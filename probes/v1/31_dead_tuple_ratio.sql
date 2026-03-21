-- Probe: dead_tuple_ratio
-- Purpose: Detect likely vacuum lag and bloat pressure.
-- Prerequisites: None
-- Profiles: default, performance, reliability

SELECT
  schemaname,
  relname,
  n_live_tup,
  n_dead_tup,
  ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_tuple_pct,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE n_live_tup + n_dead_tup > 0
ORDER BY dead_tuple_pct DESC, n_dead_tup DESC
LIMIT 30;
