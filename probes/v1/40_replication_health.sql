-- Probe: replication_health
-- Purpose: Assess lag and replica posture.
-- Prerequisites: None (but output depends on primary vs replica context)
-- Profiles: default, reliability, cost_capacity
-- Note: Severity depends on workload and whether replicas serve reads.

-- Run on primary: replication status
SELECT
  application_name,
  client_addr,
  state,
  sync_state,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication;

-- Run on replica: replay delay
SELECT
  pg_is_in_recovery() AS in_recovery,
  now() - pg_last_xact_replay_timestamp() AS replay_delay;
