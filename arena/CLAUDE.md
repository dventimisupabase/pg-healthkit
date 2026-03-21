# arena/

- DO use Supabase as the backend (Postgres + Edge Functions + Auth)
- DO use Next.js for the frontend
- DO read `../docs/04_data_model.md` for the schema — implement it as the first migration
- DO read `../contracts/rules.yaml` and `../docs/09_rule_engine.md` before implementing the rule engine
- DO read `../docs/08_cli_contract.md` — the Arena implements these API endpoints
- DO validate incoming evidence payloads against `../contracts/probe_registry.yaml`
- DO store assessments, inputs, evidence, findings, scores, reports, and events
- DO implement evidence → findings and findings → scores as SQL views and functions in the database
- DO initialize domain scores at 100, apply additive deltas, clamp to 0–100
- DO weight overall scores by assessment profile
- DO render reports from `../docs/sample_report_template.md` — reports may invoke other sources (e.g. agentic AI)
- DO tag system-schema findings as "platform" to distinguish from user-schema issues
- DO NOT use application code, Edge Functions, or external services to transform evidence into findings or findings into scores — that logic belongs in SQL views and functions
- DO NOT execute SQL probes against customer databases — that's the CLI's job
- DO NOT normalize raw probe output — that's the CLI's job
