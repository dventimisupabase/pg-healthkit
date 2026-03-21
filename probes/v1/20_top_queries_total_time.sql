-- Probe: top_queries_total_time
-- Purpose: Identify the queries consuming the most total execution time.
-- Prerequisites: pg_stat_statements extension
-- Profiles: default, performance, cost_capacity

SELECT
  queryid,
  calls,
  total_exec_time,
  mean_exec_time,
  min_exec_time,
  max_exec_time,
  stddev_exec_time,
  rows,
  shared_blks_hit,
  shared_blks_read,
  temp_blks_read,
  temp_blks_written,
  LEFT(query, 1000) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
