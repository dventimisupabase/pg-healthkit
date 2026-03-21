# arena/

- DO use Supabase as the backend (Postgres + Edge Functions + Auth)
- DO use Next.js for the frontend
- DO read `../docs/03_data_model.md` for the schema — implement it as the first migration
- DO read `../contracts/rules.yaml` and `../contracts/rules.md` before implementing the rule engine
- DO read `../contracts/cli_contract.md` — the Arena implements these API endpoints
- DO validate incoming evidence payloads against `../contracts/probe_registry.yaml`
- DO store assessments, inputs, evidence, findings, scores, reports, and events
- DO evaluate rules server-side to centralize rule evolution
- DO initialize domain scores at 100, apply additive deltas, clamp to 0–100
- DO weight overall scores by assessment profile
- DO render reports from `../docs/sample_report_template.md`
- DO tag system-schema findings as "platform" to distinguish from user-schema issues
- DO NOT execute SQL probes against customer databases — that's the CLI's job
- DO NOT normalize raw probe output — that's the CLI's job
