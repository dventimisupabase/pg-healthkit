-- probe: instance_metadata
-- purpose: Establish technical context for the rest of the assessment.
-- prerequisites: none
-- profiles: default, performance, reliability, cost_capacity

SELECT
  current_database() AS db,
  version() AS version,
  current_setting('server_version_num')::int AS server_version_num,
  pg_is_in_recovery() AS is_replica,
  current_setting('max_connections') AS max_connections,
  current_setting('shared_buffers') AS shared_buffers,
  current_setting('work_mem') AS work_mem,
  current_setting('maintenance_work_mem') AS maintenance_work_mem,
  current_setting('effective_cache_size') AS effective_cache_size,
  current_setting('max_wal_size') AS max_wal_size,
  current_setting('checkpoint_timeout') AS checkpoint_timeout,
  current_setting('autovacuum') AS autovacuum,
  current_setting('random_page_cost') AS random_page_cost,
  current_setting('log_min_duration_statement') AS log_min_duration_statement,
  current_setting('track_io_timing') AS track_io_timing,
  current_setting('shared_preload_libraries') AS shared_preload_libraries;
