-- probe: top_queries_mean_latency
-- purpose: Identify slow queries on a per-call basis.
-- prerequisites: pg_stat_statements
-- profiles: default, performance

SELECT
  queryid,
  calls,
  mean_exec_time AS mean_exec_time_ms,
  max_exec_time AS max_exec_time_ms,
  stddev_exec_time AS stddev_exec_time_ms,
  total_exec_time AS total_exec_time_ms,
  rows,
  shared_blks_hit,
  shared_blks_read,
  temp_blks_written,
  LEFT(query, 1000) AS query
FROM pg_stat_statements
WHERE calls > 10
ORDER BY mean_exec_time DESC
LIMIT 20;
