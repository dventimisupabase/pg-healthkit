-- probe: replication_health
-- purpose: Assess lag and replica posture.
-- prerequisites: none (contextual — run if replication is relevant)
-- profiles: default, reliability
--
-- On a primary, this returns replica lag information.
-- On a replica, run the replica query below instead.

-- Primary view:
SELECT
  application_name,
  client_addr,
  state,
  sync_state,
  EXTRACT(EPOCH FROM write_lag)::numeric * 1000 AS write_lag_ms,
  EXTRACT(EPOCH FROM flush_lag)::numeric * 1000 AS flush_lag_ms,
  EXTRACT(EPOCH FROM replay_lag)::numeric * 1000 AS replay_lag_ms
FROM pg_stat_replication;

-- Replica view (run separately if pg_is_in_recovery() = true):
-- SELECT
--   pg_is_in_recovery() AS in_recovery,
--   EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::numeric * 1000 AS replay_delay_ms;
