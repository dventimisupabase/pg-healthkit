-- probe: auth_schema_health
-- purpose: Detect bloat and vacuum lag on Supabase Auth tables.
-- prerequisites: auth schema exists
-- profiles: default, reliability, cost_capacity, supabase_default
-- note: Supabase-specific. Auth tables (sessions, refresh_tokens) churn heavily.

SELECT
  schemaname,
  relname,
  n_live_tup,
  n_dead_tup,
  ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_tuple_pct,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze,
  pg_total_relation_size(relid) AS total_bytes
FROM pg_stat_user_tables
WHERE schemaname = 'auth'
  AND relname IN ('users', 'sessions', 'refresh_tokens', 'mfa_factors')
ORDER BY pg_total_relation_size(relid) DESC;
