-- probe: top_queries_total_time
-- purpose: Identify the queries consuming the most total execution time.
-- prerequisites: pg_stat_statements
-- profiles: default, performance, cost_capacity, supabase_default

SELECT
  queryid,
  calls,
  total_exec_time AS total_exec_time_ms,
  mean_exec_time AS mean_exec_time_ms,
  min_exec_time AS min_exec_time_ms,
  max_exec_time AS max_exec_time_ms,
  stddev_exec_time AS stddev_exec_time_ms,
  rows,
  shared_blks_hit,
  shared_blks_read,
  temp_blks_read,
  temp_blks_written,
  LEFT(query, 1000) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
