-- probe: temp_spill_queries
-- purpose: Detect queries spilling to temp files due to sort/hash pressure.
-- prerequisites: pg_stat_statements
-- profiles: default, performance, cost_capacity

SELECT
  queryid,
  calls,
  temp_blks_read,
  temp_blks_written,
  total_exec_time AS total_exec_time_ms,
  mean_exec_time AS mean_exec_time_ms,
  LEFT(query, 1000) AS query
FROM pg_stat_statements
WHERE temp_blks_read > 0 OR temp_blks_written > 0
ORDER BY temp_blks_written DESC, temp_blks_read DESC
LIMIT 20;
