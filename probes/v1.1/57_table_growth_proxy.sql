-- Probe: table_growth_proxy
-- Purpose: Record current table sizes for future growth comparison.
-- Prerequisites: None
-- Category: v1.1 optional
-- Note: True growth rate requires history, not a single snapshot.
--       Do not pretend otherwise. Record current sizes and recommend repeat sampling.

SELECT
  schemaname,
  relname,
  pg_total_relation_size(relid) AS total_bytes
FROM pg_stat_user_tables
ORDER BY total_bytes DESC
LIMIT 100;
