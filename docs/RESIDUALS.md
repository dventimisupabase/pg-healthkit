# Residuals

Issues identified by `/grok` that require human judgment to resolve. Items are never automatically removed — manage this file manually.

---

## Gap: `supabase_default` profile inheritance not encoded in contracts

- **Found in**: `contracts/probe_registry.yaml` (profiles list per probe), `docs/07_probe_system.md` (section "Probe Profiles" / `supabase_default`)
- **Problem**: `docs/07_probe_system.md` states that `supabase_default` includes "All probes from `default`, plus all Supabase-specific probes (60-69)." However, in `contracts/probe_registry.yaml`, generic probes (instance_metadata, extensions_inventory, etc.) only list `[default, performance, reliability, cost_capacity]` in their profiles — they do not list `supabase_default`. This means an implementation reading the registry literally would not include generic probes in the `supabase_default` profile. The intent is that `supabase_default` inherits from `default`, but this inheritance is not encoded in the contract. Either the registry needs to add `supabase_default` to every generic probe's profiles list, or the contract needs to formally define profile inheritance so the implementation knows `supabase_default` implicitly includes all `default` probes.
- **Why it needs human input**: This is a design decision about whether profile inheritance should be explicit (list every profile per probe) or implicit (define inheritance rules). Both approaches have tradeoffs for maintainability and clarity.
- **Detected**: 2026-03-20

## Inconsistency: `wal_checkpoint_health` SQL column names lack `_ms` suffix required by registry

- **Found in**: `probes/41_wal_checkpoint_health.sql`, `contracts/probe_registry.yaml` (wal_checkpoint_health payload_contract)
- **Problem**: The SQL probe outputs `checkpoint_write_time` and `checkpoint_sync_time` (raw PostgreSQL column names from `pg_stat_bgwriter`), but the registry contract expects `checkpoint_write_time_ms` and `checkpoint_sync_time_ms`. The raw PG columns are already in milliseconds, so the values are correct but the names differ. The normalizer must rename these, but this mapping is not documented in `docs/15_normalizer.md`. Either the SQL aliases should be renamed to include `_ms` to match the contract, or `docs/15_normalizer.md` should document this mapping explicitly in a wal_checkpoint_health derivation section.
- **Why it needs human input**: Renaming SQL aliases changes the raw output format for manual `psql` users. A human should decide whether to prioritize SQL readability (matching PG column names) or contract alignment (adding `_ms` suffix in SQL).
- **Detected**: 2026-03-20

## Gap: `pgbouncer_pool_health` SQL probe cannot produce required registry fields

- **Found in**: `probes/65_pgbouncer_pool_health.sql`, `contracts/probe_registry.yaml` (pgbouncer_pool_health payload_contract)
- **Problem**: The registry requires `summary.active_connections` and `summary.waiting_clients`, but the fallback SQL probe queries `pg_stat_activity` which cannot determine `waiting_clients` (clients queued for a pool connection). The SQL outputs `active` (not `active_connections`) and has no `waiting_clients` column at all. The registry notes acknowledge that `pool_mode` requires platform metadata, but the `waiting_clients` gap is not addressed. The primary PgBouncer `SHOW POOLS` commands are commented out in the probe, meaning the probe as written cannot satisfy its own contract.
- **Why it needs human input**: This requires a decision about the probe implementation strategy: should the SQL probe be rewritten to target the PgBouncer admin interface, should the normalizer synthesize missing fields as null, or should the registry contract be relaxed to make `waiting_clients` optional?
- **Detected**: 2026-03-20

## Gap: `docs/15_normalizer.md` missing probe-specific derivation for all 9 Supabase probes

- **Found in**: `docs/15_normalizer.md` (section "Probe-Specific Summary Derivation")
- **Problem**: The normalizer doc provides detailed probe-specific summary derivation rules for all 16 generic probes (instance_metadata through wal_checkpoint_health) but contains no derivation guidance for any of the 9 Supabase-specific probes (rls_policy_column_indexing, realtime_replication_slot_health, auth_schema_health, storage_objects_health, system_schema_bloat, pgbouncer_pool_health, pg_cron_job_health, extension_version_health, pgvector_index_health). The registry defines the summary fields these probes must produce, but the normalizer doc does not document how to compute them from raw SQL output.
- **Why it needs human input**: Writing derivation rules requires understanding specific normalization logic decisions for each Supabase probe (e.g., how to compute `sessions_row_count` from `auth_schema_health` rows, how to derive `misconfigured_index_count` for pgvector). These decisions should be made by someone who understands the probe semantics and normalizer implementation.
- **Detected**: 2026-03-20
