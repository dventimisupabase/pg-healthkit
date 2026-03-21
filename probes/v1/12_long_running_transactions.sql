-- Probe: long_running_transactions
-- Purpose: Detect transaction behavior that harms vacuum, contention, and reliability.
-- Prerequisites: None
-- Profiles: default, performance, reliability
-- Note: One of the best v1 probes. High signal, low ambiguity.

SELECT
  pid,
  usename,
  application_name,
  client_addr,
  state,
  now() - xact_start AS xact_age,
  now() - query_start AS query_age,
  wait_event_type,
  wait_event,
  LEFT(query, 500) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND datname = current_database()
ORDER BY xact_start ASC
LIMIT 20;
