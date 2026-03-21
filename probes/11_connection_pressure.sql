-- probe: connection_pressure
-- purpose: Understand whether connection management is a risk.
-- prerequisites: none
-- profiles: default, performance, reliability, supabase_default

-- Part 1: Session state summary
SELECT
  COUNT(*) AS total_connections,
  COUNT(*) FILTER (WHERE state = 'active') AS active,
  COUNT(*) FILTER (WHERE state = 'idle') AS idle,
  COUNT(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_transaction,
  current_setting('max_connections')::int AS max_connections,
  ROUND(100.0 * COUNT(*) / current_setting('max_connections')::int, 2) AS utilization_pct
FROM pg_stat_activity
WHERE datname = current_database();

-- Part 2: Grouped by state and wait event
-- SELECT
--   state,
--   wait_event_type,
--   wait_event,
--   COUNT(*) AS sessions
-- FROM pg_stat_activity
-- WHERE datname = current_database()
-- GROUP BY 1, 2, 3
-- ORDER BY sessions DESC;
