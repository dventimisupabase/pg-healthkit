# Residuals

Issues identified by `/grok` that require human judgment to resolve. Items are never automatically removed — manage this file manually.

---

## Gap: `supabase_default` profile inheritance not encoded in contracts

- **Found in**: `contracts/probe_registry.yaml` (profiles list per probe), `docs/07_probe_system.md` (section "Probe Profiles" / `supabase_default`)
- **Problem**: `docs/07_probe_system.md` states that `supabase_default` includes "All probes from `default`, plus all Supabase-specific probes (60-69)." However, in `contracts/probe_registry.yaml`, generic probes (instance_metadata, extensions_inventory, etc.) only list `[default, performance, reliability, cost_capacity]` in their profiles — they do not list `supabase_default`. This means an implementation reading the registry literally would not include generic probes in the `supabase_default` profile. The intent is that `supabase_default` inherits from `default`, but this inheritance is not encoded in the contract. Either the registry needs to add `supabase_default` to every generic probe's profiles list, or the contract needs to formally define profile inheritance so the implementation knows `supabase_default` implicitly includes all `default` probes.
- **Why it needs human input**: This is a design decision about whether profile inheritance should be explicit (list every profile per probe) or implicit (define inheritance rules). Both approaches have tradeoffs for maintainability and clarity.
- **Detected**: 2026-03-20
