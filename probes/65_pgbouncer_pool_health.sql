-- probe: pgbouncer_pool_health
-- purpose: Detect connection pool mode and contention.
-- prerequisites: PgBouncer/Supavisor metrics accessible
-- profiles: default, performance
-- note: Supabase-specific. This probe must be run against the PgBouncer admin
--        database or via Supavisor metrics, not the application database.
--        The SQL below is for PgBouncer's SHOW commands; adapt for Supavisor.

-- Run against PgBouncer admin database:
-- SHOW POOLS;
-- SHOW CONFIG;

-- Fallback: detect pool mode indirectly from application database.
-- If PgBouncer is in transaction mode, prepared statements will fail.
-- This query checks for signs of pooler presence.
SELECT
  COUNT(*) AS total_connections,
  COUNT(DISTINCT client_addr) AS distinct_clients,
  COUNT(*) FILTER (WHERE application_name LIKE '%pgbouncer%' OR application_name LIKE '%supavisor%') AS pooler_connections,
  COUNT(*) FILTER (WHERE state = 'active') AS active,
  COUNT(*) FILTER (WHERE state = 'idle') AS idle,
  COUNT(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_transaction,
  current_setting('max_connections')::int AS max_connections
FROM pg_stat_activity
WHERE datname = current_database();
