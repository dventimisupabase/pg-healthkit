-- probe: long_running_transactions
-- purpose: Detect transaction behavior that harms vacuum, contention, and reliability.
-- prerequisites: none
-- profiles: default, performance, reliability

SELECT
  pid,
  usename,
  application_name,
  client_addr,
  state,
  EXTRACT(EPOCH FROM (now() - xact_start))::int AS xact_age_seconds,
  EXTRACT(EPOCH FROM (now() - query_start))::int AS query_age_seconds,
  wait_event_type,
  wait_event,
  LEFT(query, 1000) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND datname = current_database()
ORDER BY xact_start ASC
LIMIT 20;
