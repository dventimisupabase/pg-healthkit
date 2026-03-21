# pg-healthkit

- DO read `docs/01_methodology.md` before writing any code
- DO treat `contracts/` as the source of truth for the boundary between `cli/` and `arena/`
- DO work in `cli/` for probe execution, normalization, and upload
- DO work in `arena/` for assessment storage, rules, scoring, reporting, and UI
- DO NOT create dependencies between `cli/` and `arena/` — they communicate only through `contracts/`
- DO NOT put rule evaluation or scoring logic in `cli/`
- DO NOT put SQL probe execution or normalization in `arena/`
- DO NOT blur the layers: probes collect, normalizers shape, rules interpret, scores summarize, reports render
- DO prefer boring, explicit code over clever abstractions
- DO test against fixtures derived from contracts
- DO write the CLI in Go — this is a Supabase CLI plugin and Supabase CLI is Go
