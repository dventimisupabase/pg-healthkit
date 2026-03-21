-- Probe: sequential_scan_heavy_tables
-- Purpose: Identify tables with high sequential scan activity relative to index scans.
-- Prerequisites: None
-- Category: v1.1 optional
-- Note: For OLTP this is often a useful smell, not automatically a bug.

SELECT
  schemaname,
  relname,
  seq_scan,
  idx_scan,
  n_live_tup,
  ROUND(seq_scan::numeric / NULLIF(idx_scan, 0), 2) AS seq_to_idx_ratio
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_scan DESC
LIMIT 30;
