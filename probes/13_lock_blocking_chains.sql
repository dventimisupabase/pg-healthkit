-- probe: lock_blocking_chains
-- purpose: Detect active blocking and lock contention.
-- prerequisites: none
-- profiles: default, performance, reliability

WITH blocked AS (
  SELECT
    a.pid AS blocked_pid,
    a.usename AS blocked_user,
    a.application_name AS blocked_app,
    a.query AS blocked_query,
    a.wait_event_type,
    a.wait_event,
    pg_blocking_pids(a.pid) AS blockers
  FROM pg_stat_activity a
  WHERE cardinality(pg_blocking_pids(a.pid)) > 0
)
SELECT
  b.blocked_pid,
  b.blocked_user,
  b.blocked_app,
  b.wait_event_type,
  b.wait_event,
  blocker.pid AS blocker_pid,
  blocker.usename AS blocker_user,
  blocker.application_name AS blocker_app,
  LEFT(b.blocked_query, 500) AS blocked_query,
  LEFT(blocker.query, 500) AS blocker_query
FROM blocked b
JOIN LATERAL unnest(b.blockers) AS blocker_pid(pid) ON true
JOIN pg_stat_activity blocker ON blocker.pid = blocker_pid.pid
ORDER BY b.blocked_pid;
