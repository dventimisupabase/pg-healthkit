-- Probe: stale_maintenance
-- Purpose: Detect tables not being vacuumed/analyzed adequately.
-- Prerequisites: None
-- Profiles: default, performance, reliability

SELECT
  schemaname,
  relname,
  n_live_tup,
  n_dead_tup,
  last_autovacuum,
  last_autoanalyze,
  vacuum_count,
  autovacuum_count,
  analyze_count,
  autoanalyze_count
FROM pg_stat_user_tables
ORDER BY COALESCE(last_autoanalyze, last_analyze, '1900-01-01'::timestamp) ASC
LIMIT 30;
