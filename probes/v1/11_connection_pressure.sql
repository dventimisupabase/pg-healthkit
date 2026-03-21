-- Probe: connection_pressure
-- Purpose: Understand whether connection management is a risk.
-- Prerequisites: None
-- Profiles: default, performance, reliability, cost_capacity

-- Part 1: Session state breakdown
SELECT
  state,
  wait_event_type,
  wait_event,
  COUNT(*) AS sessions
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY 1, 2, 3
ORDER BY sessions DESC;

-- Part 2: Connection summary
SELECT
  COUNT(*) AS total_connections,
  COUNT(*) FILTER (WHERE state = 'active') AS active,
  COUNT(*) FILTER (WHERE state = 'idle') AS idle,
  COUNT(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_transaction
FROM pg_stat_activity
WHERE datname = current_database();
