-- probe: largest_tables
-- purpose: Identify storage concentration and likely maintenance hotspots.
-- prerequisites: none
-- profiles: default, reliability, cost_capacity

SELECT
  schemaname,
  relname,
  pg_total_relation_size(relid) AS total_bytes,
  pg_relation_size(relid) AS table_bytes,
  pg_indexes_size(relid) AS index_bytes,
  n_live_tup,
  n_dead_tup
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 30;
