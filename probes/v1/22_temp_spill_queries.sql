-- Probe: temp_spill_queries
-- Purpose: Detect queries spilling to temp files due to sort/hash pressure.
-- Prerequisites: pg_stat_statements extension
-- Profiles: default, performance, cost_capacity

SELECT
  queryid,
  calls,
  temp_blks_read,
  temp_blks_written,
  total_exec_time,
  mean_exec_time,
  LEFT(query, 1000) AS query
FROM pg_stat_statements
WHERE temp_blks_read > 0 OR temp_blks_written > 0
ORDER BY temp_blks_written DESC, temp_blks_read DESC
LIMIT 20;
