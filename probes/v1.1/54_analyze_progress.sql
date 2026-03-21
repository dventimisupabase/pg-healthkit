-- Probe: analyze_progress
-- Purpose: Show currently running analyze operations and their progress.
-- Prerequisites: None
-- Category: v1.1 optional

SELECT
  pid,
  relid::regclass AS relation,
  phase,
  sample_blks_total,
  sample_blks_scanned,
  ext_stats_total,
  ext_stats_computed
FROM pg_stat_progress_analyze;
