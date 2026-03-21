-- probe: database_activity
-- purpose: Capture database-wide workload and pressure signals.
-- prerequisites: none
-- profiles: default, performance, reliability
-- note: Cumulative stats; depends on stats reset horizon.

SELECT
  datname,
  numbackends,
  xact_commit,
  xact_rollback,
  blks_read,
  blks_hit,
  tup_returned,
  tup_fetched,
  tup_inserted,
  tup_updated,
  tup_deleted,
  temp_files,
  temp_bytes,
  deadlocks,
  blk_read_time,
  blk_write_time,
  stats_reset
FROM pg_stat_database
WHERE datname = current_database();
