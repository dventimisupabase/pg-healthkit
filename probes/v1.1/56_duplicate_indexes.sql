-- Probe: duplicate_indexes
-- Purpose: Detect duplicate or overlapping indexes (heuristic only).
-- Prerequisites: None
-- Category: v1.1 optional

SELECT
  indrelid::regclass AS table_name,
  indexrelid::regclass AS index_name,
  pg_get_indexdef(indexrelid) AS index_def
FROM pg_index
WHERE indrelid IN (
  SELECT indrelid
  FROM pg_index
  GROUP BY indrelid, indkey
  HAVING COUNT(*) > 1
)
ORDER BY table_name::text, index_name::text;
