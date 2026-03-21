# cli/

- DO write Go
- DO read `../contracts/probe_registry.yaml` before implementing any probe
- DO read `../docs/15_normalizer.md` before implementing normalization
- DO read `../docs/08_cli_contract.md` for command surface and JSON payloads
- DO execute SQL probes, normalize results, validate against registry, upload to Arena
- DO make probes executable standalone via `psql`
- DO name SQL files `NN_probe_name.sql` in `probes/`
- DO test each probe for: success with rows, success with zero rows, skipped, failed
- DO use fixtures in `testdata/`
- DO start with `long_running_transactions` as the first vertical slice
- DO add `rls_policy_column_indexing` early for Supabase deployments
- DO NOT evaluate rules or produce findings
- DO NOT compute scores
- DO NOT generate reports
- DO NOT store assessment state — that's the Arena's job
