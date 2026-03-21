-- Probe: largest_tables
-- Purpose: Identify storage concentration and likely maintenance hotspots.
-- Prerequisites: None
-- Profiles: default, performance, reliability, cost_capacity

SELECT
  schemaname,
  relname,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
  pg_size_pretty(pg_relation_size(relid)) AS table_size,
  pg_size_pretty(pg_indexes_size(relid)) AS indexes_size,
  n_live_tup,
  n_dead_tup
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 30;
