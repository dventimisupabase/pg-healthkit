-- Probe: vacuum_progress
-- Purpose: Show currently running vacuum operations and their progress.
-- Prerequisites: None
-- Category: v1.1 optional

SELECT
  pid,
  relid::regclass AS relation,
  phase,
  heap_blks_total,
  heap_blks_scanned,
  heap_blks_vacuumed,
  index_vacuum_count,
  max_dead_tuples,
  num_dead_tuples
FROM pg_stat_progress_vacuum;
