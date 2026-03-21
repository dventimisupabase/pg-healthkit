-- probe: unused_indexes
-- purpose: Detect likely write/storage waste from unused indexes.
-- prerequisites: none
-- profiles: default, cost_capacity
-- note: Medium-confidence unless stats age is known and representative.

SELECT
  s.schemaname,
  s.relname AS table_name,
  s.indexrelname AS index_name,
  s.idx_scan,
  pg_relation_size(s.indexrelid) AS index_bytes
FROM pg_stat_user_indexes s
WHERE s.idx_scan = 0
ORDER BY pg_relation_size(s.indexrelid) DESC
LIMIT 30;
