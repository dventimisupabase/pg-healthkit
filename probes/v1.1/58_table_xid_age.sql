-- Probe: table_xid_age
-- Purpose: Detect tables approaching transaction ID wraparound risk.
-- Prerequisites: None
-- Category: v1.1 optional
-- Note: Tables with very high xid age can trigger forced autovacuum or,
--   in extreme cases, database shutdown to prevent wraparound.

SELECT
  schemaname,
  relname,
  age(relfrozenxid) AS xid_age,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
  n_live_tup,
  last_autovacuum,
  last_vacuum
FROM pg_stat_user_tables
ORDER BY age(relfrozenxid) DESC
LIMIT 30;
