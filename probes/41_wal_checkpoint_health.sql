-- probe: wal_checkpoint_health
-- purpose: Assess checkpoint and background writer pressure.
-- prerequisites: none (pg_stat_wal available on PG 14+)
-- profiles: default, reliability, cost_capacity, supabase_default

-- Background writer / checkpoint stats (all versions)
SELECT
  checkpoints_timed,
  checkpoints_req,
  checkpoint_write_time AS checkpoint_write_time_ms,
  checkpoint_sync_time AS checkpoint_sync_time_ms,
  buffers_checkpoint,
  buffers_clean,
  maxwritten_clean,
  buffers_backend,
  buffers_backend_fsync,
  buffers_alloc
FROM pg_stat_bgwriter;

-- WAL stats (PG 14+, run separately or combine in normalizer)
-- SELECT *
-- FROM pg_stat_wal;
