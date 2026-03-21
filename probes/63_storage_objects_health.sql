-- probe: storage_objects_health
-- purpose: Detect growth pressure and cleanup lag on storage.objects.
-- prerequisites: storage schema exists
-- profiles: default, cost_capacity, supabase_default
-- note: Supabase-specific. Soft-deleted rows waste storage and slow queries.

SELECT
  'storage' AS schemaname,
  'objects' AS relname,
  (SELECT COUNT(*) FROM storage.objects) AS total_rows,
  (SELECT COUNT(*) FROM storage.objects WHERE deleted_at IS NOT NULL) AS soft_deleted_rows,
  ROUND(
    100.0 * (SELECT COUNT(*) FROM storage.objects WHERE deleted_at IS NOT NULL)
    / NULLIF((SELECT COUNT(*) FROM storage.objects), 0),
    2
  ) AS soft_deleted_ratio,
  s.n_live_tup,
  s.n_dead_tup,
  ROUND(100.0 * s.n_dead_tup / NULLIF(s.n_live_tup + s.n_dead_tup, 0), 2) AS dead_tuple_pct,
  s.last_autovacuum,
  s.last_autoanalyze,
  pg_total_relation_size(s.relid) AS total_bytes
FROM pg_stat_user_tables s
WHERE s.schemaname = 'storage'
  AND s.relname = 'objects';
