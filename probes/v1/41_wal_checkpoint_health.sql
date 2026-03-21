-- Probe: wal_checkpoint_health
-- Purpose: Assess checkpoint and background writer pressure.
-- Prerequisites: None (pg_stat_wal requires PG 14+)
-- Profiles: default, reliability, cost_capacity

-- Checkpoint and bgwriter stats (all versions)
SELECT
  checkpoints_timed,
  checkpoints_req,
  checkpoint_write_time,
  checkpoint_sync_time,
  buffers_checkpoint,
  buffers_clean,
  maxwritten_clean,
  buffers_backend,
  buffers_backend_fsync,
  buffers_alloc
FROM pg_stat_bgwriter;

-- WAL stats (PG 14+; will error on older versions)
SELECT *
FROM pg_stat_wal;
