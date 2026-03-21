-- probe: wal_checkpoint_health
-- purpose: Assess checkpoint and background writer pressure.
-- prerequisites: none
-- profiles: default, reliability, cost_capacity, supabase_default
-- note: PG 17+ moved checkpoint stats from pg_stat_bgwriter to pg_stat_checkpointer.
--        This query dynamically detects the schema version.

DROP TABLE IF EXISTS _hk_checkpoint_stats;

CREATE TEMP TABLE _hk_checkpoint_stats (
  checkpoints_timed bigint,
  checkpoints_req bigint,
  checkpoint_write_time_ms double precision,
  checkpoint_sync_time_ms double precision,
  buffers_checkpoint bigint,
  buffers_clean bigint,
  maxwritten_clean bigint,
  buffers_backend bigint,
  buffers_backend_fsync bigint,
  buffers_alloc bigint
);

DO $$
BEGIN
  IF current_setting('server_version_num')::int >= 170000 THEN
    INSERT INTO _hk_checkpoint_stats
    SELECT
      c.num_timed,
      c.num_requested,
      c.write_time,
      c.sync_time,
      c.buffers_written,
      b.buffers_clean,
      b.maxwritten_clean,
      0::bigint,
      0::bigint,
      b.buffers_alloc
    FROM pg_stat_checkpointer c
    CROSS JOIN pg_stat_bgwriter b;
  ELSE
    EXECUTE '
      INSERT INTO _hk_checkpoint_stats
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
      FROM pg_stat_bgwriter';
  END IF;
END $$;

SELECT * FROM _hk_checkpoint_stats;
