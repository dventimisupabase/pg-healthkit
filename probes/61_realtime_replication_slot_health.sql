-- probe: realtime_replication_slot_health
-- purpose: Detect unconsumed or lagging logical replication slots (Supabase Realtime).
-- prerequisites: Realtime enabled
-- profiles: default, reliability
-- note: Supabase-specific. Inactive slots prevent WAL cleanup and can fill disk.

SELECT
  slot_name,
  slot_type,
  active,
  xmin,
  confirmed_flush_lsn,
  pg_current_wal_lsn() AS current_wal_lsn,
  pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) AS lag_bytes
FROM pg_replication_slots
ORDER BY lag_bytes DESC NULLS LAST;
