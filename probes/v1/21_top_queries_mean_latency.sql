-- Probe: top_queries_mean_latency
-- Purpose: Identify slow queries on a per-call basis.
-- Prerequisites: pg_stat_statements extension
-- Profiles: default, performance

SELECT
  queryid,
  calls,
  mean_exec_time,
  total_exec_time,
  rows,
  shared_blks_hit,
  shared_blks_read,
  temp_blks_written,
  LEFT(query, 1000) AS query
FROM pg_stat_statements
WHERE calls > 10
ORDER BY mean_exec_time DESC
LIMIT 20;
