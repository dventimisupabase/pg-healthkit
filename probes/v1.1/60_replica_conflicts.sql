-- Probe: replica_conflicts
-- Purpose: Detect query cancellations and conflict events on replicas.
-- Prerequisites: Database is a streaming replica (pg_is_in_recovery() = true)
-- Category: v1.1 optional
-- Note: Conflicts occur when the primary's cleanup operations (vacuum,
--   buffer cleanup) conflict with long-running queries on the replica.

SELECT
  datname,
  confl_tablespace,
  confl_lock,
  confl_snapshot,
  confl_bufferpin,
  confl_deadlock
FROM pg_stat_database_conflicts
WHERE datname = current_database();
