-- Probe: cache_hit_ratio
-- Purpose: Directional signal for buffer cache efficiency.
-- Prerequisites: None
-- Category: v1.1 optional
-- Note: Use cautiously; this is a directional signal, not a health score by itself.

SELECT
  datname,
  blks_hit,
  blks_read,
  ROUND(
    100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0),
    2
  ) AS cache_hit_pct
FROM pg_stat_database
WHERE datname = current_database();
