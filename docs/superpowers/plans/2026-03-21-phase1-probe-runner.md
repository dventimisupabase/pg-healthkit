# Phase 1: CLI Probe Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Go CLI that loads the probe registry, connects to a PostgreSQL database, executes probes filtered by profile, normalizes results into canonical payloads, validates against contracts, and emits JSON to stdout.

**Architecture:** Four internal packages (`registry`, `probe`, `normalize`, `validate`) wired together by a thin `main.go`. Contract-driven type coercion with probe-specific summary derivation functions. pgx for database access, yaml.v3 for registry parsing.

**Tech Stack:** Go 1.22+, pgx/v5, gopkg.in/yaml.v3, stdlib

**Spec:** `docs/superpowers/specs/2026-03-21-phase1-probe-runner-design.md`

**Key Reference Files:**
- `contracts/probe_registry.yaml` — canonical payload contracts
- `docs/15_normalizer.md` — normalization rules and summary derivation
- `probes/*.sql` — SQL probe files

---

## File Structure

```
cli/
  cmd/healthkit/main.go              # Entry point: flags, orchestration, JSON output
  internal/
    registry/
      registry.go                    # Parse probe_registry.yaml into Go structs
      registry_test.go               # Test parsing, profile filtering, prerequisites
    probe/
      runner.go                      # pgx connection, SQL execution, raw row capture
      runner_test.go                 # Integration tests (build-tagged)
    normalize/
      normalize.go                   # Generic type coercion + canonical envelope
      summary.go                     # Probe-specific summary derivation functions
      normalize_test.go              # Fixture-driven normalization tests
    validate/
      validate.go                    # Validate canonical payloads against contracts
      validate_test.go               # Valid/invalid payload tests
  testdata/
    raw/
      instance_metadata.json         # Raw pgx output fixture
      long_running_transactions.json
      connection_pressure.json
    canonical/
      instance_metadata.json         # Expected normalized payload
      long_running_transactions.json
      connection_pressure.json
  go.mod
  go.sum
```

---

## Task 1: Go Module and Package Scaffolding

**Files:**
- Create: `cli/go.mod`
- Create: `cli/cmd/healthkit/main.go`
- Create: `cli/internal/registry/registry.go`
- Create: `cli/internal/probe/runner.go`
- Create: `cli/internal/normalize/normalize.go`
- Create: `cli/internal/normalize/summary.go`
- Create: `cli/internal/validate/validate.go`

- [ ] **Step 1: Initialize Go module**

```bash
cd cli && go mod init github.com/dventimisupabase/pg-healthkit/cli
```

- [ ] **Step 2: Create stub files for all packages**

`cli/cmd/healthkit/main.go`:
```go
package main

import "fmt"

func main() {
	fmt.Println("healthkit: not yet implemented")
}
```

`cli/internal/registry/registry.go`:
```go
package registry
```

`cli/internal/probe/runner.go`:
```go
package probe
```

`cli/internal/normalize/normalize.go`:
```go
package normalize
```

`cli/internal/normalize/summary.go`:
```go
package normalize
```

`cli/internal/validate/validate.go`:
```go
package validate
```

- [ ] **Step 3: Verify build**

```bash
cd cli && go build ./...
```

Expected: clean build, no errors.

- [ ] **Step 4: Commit**

```bash
git add cli/
git commit -m "feat(cli): scaffold Go module and package structure"
```

---

## Task 2: Registry Loader — Types and Parsing

**Files:**
- Create: `cli/internal/registry/registry.go`
- Create: `cli/internal/registry/registry_test.go`

- [ ] **Step 1: Write the failing test — parse registry and count probes**

`cli/internal/registry/registry_test.go`:
```go
package registry_test

import (
	"testing"

	"github.com/dventimisupabase/pg-healthkit/cli/internal/registry"
)

func TestLoadRegistry(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	if len(reg.Probes) != 24 {
		t.Errorf("expected 24 probes, got %d", len(reg.Probes))
	}
	if reg.Version != "v1" {
		t.Errorf("expected version v1, got %s", reg.Version)
	}
}

func TestLoadRegistry_ProbeFields(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	// Find long_running_transactions
	var found *registry.Probe
	for i := range reg.Probes {
		if reg.Probes[i].Name == "long_running_transactions" {
			found = &reg.Probes[i]
			break
		}
	}
	if found == nil {
		t.Fatal("long_running_transactions probe not found")
	}
	if found.SQLFile != "probes/12_long_running_transactions.sql" {
		t.Errorf("unexpected sql_file: %s", found.SQLFile)
	}
	if !found.Enabled {
		t.Error("expected probe to be enabled")
	}
	if len(found.Profiles) == 0 {
		t.Error("expected at least one profile")
	}
}

func TestFilterByProfile(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	defaultProbes := reg.FilterByProfile("default")
	if len(defaultProbes) == 0 {
		t.Error("expected probes for default profile")
	}

	// All returned probes should include "default" in their profiles
	for _, p := range defaultProbes {
		hasProfile := false
		for _, prof := range p.Profiles {
			if prof == "default" {
				hasProfile = true
				break
			}
		}
		if !hasProfile {
			t.Errorf("probe %s does not include default profile", p.Name)
		}
	}

	// performance profile should exclude some probes
	perfProbes := reg.FilterByProfile("performance")
	if len(perfProbes) >= len(defaultProbes) {
		// Not necessarily true for all registries, but check it's filtering
		t.Logf("default: %d probes, performance: %d probes", len(defaultProbes), len(perfProbes))
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd cli && go test ./internal/registry/ -v
```

Expected: FAIL — `Load` function not defined.

- [ ] **Step 3: Add yaml.v3 dependency**

```bash
cd cli && go get gopkg.in/yaml.v3
```

- [ ] **Step 4: Implement registry types and loader**

`cli/internal/registry/registry.go`:
```go
package registry

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// Registry represents the parsed probe_registry.yaml.
type Registry struct {
	Version       string   `yaml:"version"`
	SchemaVersion string   `yaml:"schema_version"`
	Profiles      []string `yaml:"profiles"`
	Probes        []Probe  `yaml:"probes"`
}

// Probe represents a single probe entry in the registry.
type Probe struct {
	Name            string            `yaml:"name"`
	Version         string            `yaml:"version"`
	Enabled         bool              `yaml:"enabled"`
	Profiles        []string          `yaml:"profiles"`
	Category        string            `yaml:"category"`
	SQLFile         string            `yaml:"sql_file"`
	Prerequisites   Prerequisites     `yaml:"prerequisites"`
	PayloadContract yaml.Node         `yaml:"payload_contract"`
	SummaryFields   []string          `yaml:"summary_fields"`
	SupportFindings []string          `yaml:"supports_findings"`
	AffectsDomains  []string          `yaml:"affects_domains"`
}

// Prerequisites defines what a probe requires to run.
type Prerequisites struct {
	Extensions   []string `yaml:"extensions"`
	Capabilities []string `yaml:"capabilities"`
}

// Load reads and parses a probe_registry.yaml file.
func Load(path string) (*Registry, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading registry: %w", err)
	}

	var reg Registry
	if err := yaml.Unmarshal(data, &reg); err != nil {
		return nil, fmt.Errorf("parsing registry: %w", err)
	}

	return &reg, nil
}

// FilterByProfile returns enabled probes that include the given profile.
func (r *Registry) FilterByProfile(profile string) []Probe {
	var result []Probe
	for _, p := range r.Probes {
		if !p.Enabled {
			continue
		}
		for _, prof := range p.Profiles {
			if prof == profile {
				result = append(result, p)
				break
			}
		}
	}
	return result
}

// FindProbe returns a probe by name, or nil if not found.
func (r *Registry) FindProbe(name string) *Probe {
	for i := range r.Probes {
		if r.Probes[i].Name == name {
			return &r.Probes[i]
		}
	}
	return nil
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd cli && go test ./internal/registry/ -v
```

Expected: PASS — all 3 tests green.

- [ ] **Step 6: Commit**

```bash
git add cli/
git commit -m "feat(cli): implement registry loader with profile filtering"
```

---

## Task 3: Probe Runner — SQL Execution

**Files:**
- Create: `cli/internal/probe/runner.go`
- Create: `cli/internal/probe/runner_test.go`

- [ ] **Step 1: Write the failing test — runner types and interface**

`cli/internal/probe/runner_test.go`:
```go
//go:build integration

package probe_test

import (
	"context"
	"os"
	"testing"

	"github.com/dventimisupabase/pg-healthkit/cli/internal/probe"
	"github.com/dventimisupabase/pg-healthkit/cli/internal/registry"
)

func TestRunProbe_InstanceMetadata(t *testing.T) {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set")
	}

	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("instance_metadata")
	if p == nil {
		t.Fatal("instance_metadata probe not found in registry")
	}

	runner, err := probe.NewRunner(dsn, "../../probes")
	if err != nil {
		t.Fatalf("NewRunner: %v", err)
	}
	defer runner.Close()

	result := runner.Run(context.Background(), p)
	if result.Status != "success" {
		t.Fatalf("expected success, got %s: %v", result.Status, result.Error)
	}
	if len(result.Rows) != 1 {
		t.Errorf("expected 1 row, got %d", len(result.Rows))
	}
	if result.DurationMs <= 0 {
		t.Error("expected positive duration_ms")
	}

	row := result.Rows[0]
	if _, ok := row["server_version_num"]; !ok {
		t.Error("expected server_version_num in row")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd cli && go test ./internal/probe/ -v -tags integration
```

Expected: FAIL — `probe.NewRunner` not defined.

- [ ] **Step 3: Add pgx dependency**

```bash
cd cli && go get github.com/jackc/pgx/v5
```

- [ ] **Step 4: Implement probe runner**

`cli/internal/probe/runner.go`:
```go
package probe

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/dventimisupabase/pg-healthkit/cli/internal/registry"
)

// RawResult holds the output of a single probe execution.
type RawResult struct {
	ProbeName  string
	Rows       []map[string]any
	Status     string // "success", "failed", "skipped"
	DurationMs int64
	Error      error
	SkipReason string
}

// Runner executes SQL probes against a PostgreSQL database.
type Runner struct {
	conn      *pgx.Conn
	probesDir string
}

// NewRunner creates a runner connected to the given DSN.
func NewRunner(dsn string, probesDir string) (*Runner, error) {
	ctx := context.Background()
	conn, err := pgx.Connect(ctx, dsn)
	if err != nil {
		return nil, fmt.Errorf("connecting to database: %w", err)
	}
	return &Runner{conn: conn, probesDir: probesDir}, nil
}

// Close closes the database connection.
func (r *Runner) Close() {
	if r.conn != nil {
		r.conn.Close(context.Background())
	}
}

// Run executes a single probe and returns the raw result.
func (r *Runner) Run(ctx context.Context, p *registry.Probe) RawResult {
	result := RawResult{ProbeName: p.Name}

	sqlPath := filepath.Join(r.probesDir, filepath.Base(p.SQLFile))
	sqlBytes, err := os.ReadFile(sqlPath)
	if err != nil {
		result.Status = "failed"
		result.Error = fmt.Errorf("reading SQL file %s: %w", sqlPath, err)
		return result
	}

	start := time.Now()
	rows, err := r.conn.Query(ctx, string(sqlBytes))
	if err != nil {
		result.DurationMs = time.Since(start).Milliseconds()
		result.Status = "failed"
		result.Error = fmt.Errorf("executing probe %s: %w", p.Name, err)
		return result
	}
	defer rows.Close()

	fieldDescs := rows.FieldDescriptions()
	for rows.Next() {
		values, err := rows.Values()
		if err != nil {
			result.DurationMs = time.Since(start).Milliseconds()
			result.Status = "failed"
			result.Error = fmt.Errorf("scanning row for probe %s: %w", p.Name, err)
			return result
		}

		row := make(map[string]any, len(fieldDescs))
		for i, fd := range fieldDescs {
			row[string(fd.Name)] = values[i]
		}
		result.Rows = append(result.Rows, row)
	}

	result.DurationMs = time.Since(start).Milliseconds()
	if rows.Err() != nil {
		result.Status = "failed"
		result.Error = rows.Err()
		return result
	}

	result.Status = "success"
	return result
}

// RunWithPrereqs runs a probe, checking prerequisites first.
// instanceData should be the raw result from instance_metadata.
// extensionNames should be the list of installed extension names.
func (r *Runner) RunWithPrereqs(ctx context.Context, p *registry.Probe, extensionNames []string) RawResult {
	// Check extension prerequisites
	for _, req := range p.Prerequisites.Extensions {
		found := false
		for _, ext := range extensionNames {
			if ext == req {
				found = true
				break
			}
		}
		if !found {
			return RawResult{
				ProbeName:  p.Name,
				Status:     "skipped",
				SkipReason: fmt.Sprintf("prerequisite not met: %s extension not loaded", req),
			}
		}
	}

	return r.Run(ctx, p)
}
```

- [ ] **Step 5: Run integration test (requires DATABASE_URL)**

```bash
cd cli && DATABASE_URL="postgres://localhost:5432/postgres" go test ./internal/probe/ -v -tags integration
```

Expected: PASS if a local PostgreSQL is available, SKIP otherwise.

- [ ] **Step 6: Commit**

```bash
git add cli/
git commit -m "feat(cli): implement probe runner with pgx SQL execution"
```

---

## Task 4: Normalizer — Type Coercion and Envelope

**Files:**
- Create: `cli/internal/normalize/normalize.go`
- Create: `cli/internal/normalize/normalize_test.go`
- Create: `cli/testdata/raw/long_running_transactions.json`
- Create: `cli/testdata/canonical/long_running_transactions.json`

- [ ] **Step 1: Create raw fixture for long_running_transactions**

`cli/testdata/raw/long_running_transactions.json`:
```json
{
  "probe_name": "long_running_transactions",
  "status": "success",
  "duration_ms": 14,
  "rows": [
    {
      "pid": 12345,
      "usename": "app_user",
      "application_name": "myapp",
      "client_addr": "10.0.0.5",
      "state": "active",
      "xact_age_seconds": 120,
      "query_age_seconds": 45,
      "wait_event_type": null,
      "wait_event": null,
      "query": "SELECT * FROM orders WHERE id = 1"
    },
    {
      "pid": 12346,
      "usename": "app_user",
      "application_name": "myapp",
      "client_addr": "10.0.0.6",
      "state": "idle in transaction",
      "xact_age_seconds": 300,
      "query_age_seconds": 300,
      "wait_event_type": "Client",
      "wait_event": "ClientRead",
      "query": "UPDATE accounts SET balance = balance - 100"
    },
    {
      "pid": 12347,
      "usename": "admin",
      "application_name": "psql",
      "client_addr": null,
      "state": "active",
      "xact_age_seconds": 45,
      "query_age_seconds": 10,
      "wait_event_type": null,
      "wait_event": null,
      "query": "ANALYZE public.orders"
    }
  ]
}
```

- [ ] **Step 2: Create expected canonical fixture**

`cli/testdata/canonical/long_running_transactions.json`:
```json
{
  "probe_name": "long_running_transactions",
  "probe_version": "2026-03-20",
  "status": "success",
  "summary": {
    "row_count": 3,
    "oldest_xact_age_seconds": 300,
    "oldest_idle_xact_age_seconds": 300
  },
  "rows": [
    {
      "pid": 12345,
      "usename": "app_user",
      "application_name": "myapp",
      "client_addr": "10.0.0.5",
      "state": "active",
      "xact_age_seconds": 120,
      "query_age_seconds": 45,
      "wait_event_type": null,
      "wait_event": null,
      "query": "SELECT * FROM orders WHERE id = 1"
    },
    {
      "pid": 12346,
      "usename": "app_user",
      "application_name": "myapp",
      "client_addr": "10.0.0.6",
      "state": "idle in transaction",
      "xact_age_seconds": 300,
      "query_age_seconds": 300,
      "wait_event_type": "Client",
      "wait_event": "ClientRead",
      "query": "UPDATE accounts SET balance = balance - 100"
    },
    {
      "pid": 12347,
      "usename": "admin",
      "application_name": "psql",
      "client_addr": null,
      "state": "active",
      "xact_age_seconds": 45,
      "query_age_seconds": 10,
      "wait_event_type": null,
      "wait_event": null,
      "query": "ANALYZE public.orders"
    }
  ],
  "metadata": {
    "duration_ms": 14,
    "collector_version": "0.1.0",
    "normalizer_version": "0.1.0",
    "contract_version": "v1",
    "warnings": []
  }
}
```

- [ ] **Step 3: Write the failing test**

`cli/internal/normalize/normalize_test.go`:
```go
package normalize_test

import (
	"encoding/json"
	"fmt"
	"os"
	"testing"

	"github.com/dventimisupabase/pg-healthkit/cli/internal/normalize"
	"github.com/dventimisupabase/pg-healthkit/cli/internal/probe"
	"github.com/dventimisupabase/pg-healthkit/cli/internal/registry"
)

func loadFixture(t *testing.T, path string) []byte {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("reading fixture %s: %v", path, err)
	}
	return data
}

func TestNormalize_LongRunningTransactions(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("long_running_transactions")
	if p == nil {
		t.Fatal("probe not found")
	}

	// Load raw fixture into RawResult
	rawJSON := loadFixture(t, "../../testdata/raw/long_running_transactions.json")
	var rawFixture struct {
		Rows       []map[string]any `json:"rows"`
		DurationMs int64            `json:"duration_ms"`
	}
	if err := json.Unmarshal(rawJSON, &rawFixture); err != nil {
		t.Fatalf("unmarshal raw fixture: %v", err)
	}

	raw := probe.RawResult{
		ProbeName:  "long_running_transactions",
		Status:     "success",
		DurationMs: rawFixture.DurationMs,
		Rows:       rawFixture.Rows,
	}

	payload := normalize.Normalize(p, raw)

	if payload.ProbeName != "long_running_transactions" {
		t.Errorf("expected probe_name long_running_transactions, got %s", payload.ProbeName)
	}
	if payload.Status != "success" {
		t.Errorf("expected status success, got %s", payload.Status)
	}

	// Check summary
	rowCount, ok := payload.Summary["row_count"]
	if !ok {
		t.Fatal("missing summary.row_count")
	}
	if rowCount != 3 {
		t.Errorf("expected row_count 3, got %v", rowCount)
	}

	oldestAge, ok := payload.Summary["oldest_xact_age_seconds"]
	if !ok {
		t.Fatal("missing summary.oldest_xact_age_seconds")
	}
	if oldestAge != 300 {
		t.Errorf("expected oldest_xact_age_seconds 300, got %v", oldestAge)
	}

	oldestIdle, ok := payload.Summary["oldest_idle_xact_age_seconds"]
	if !ok {
		t.Fatal("missing summary.oldest_idle_xact_age_seconds")
	}
	if oldestIdle != 300 {
		t.Errorf("expected oldest_idle_xact_age_seconds 300, got %v", oldestIdle)
	}

	// Check rows preserved
	if len(payload.Rows) != 3 {
		t.Errorf("expected 3 rows, got %d", len(payload.Rows))
	}

	// Check metadata
	if payload.Metadata.DurationMs != 14 {
		t.Errorf("expected duration_ms 14, got %d", payload.Metadata.DurationMs)
	}
	if payload.Metadata.ContractVersion != "v1" {
		t.Errorf("expected contract_version v1, got %s", payload.Metadata.ContractVersion)
	}
}

func TestNormalize_ZeroRows(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("long_running_transactions")
	if p == nil {
		t.Fatal("probe not found")
	}

	raw := probe.RawResult{
		ProbeName:  "long_running_transactions",
		Status:     "success",
		DurationMs: 5,
		Rows:       []map[string]any{},
	}

	payload := normalize.Normalize(p, raw)

	if payload.Status != "success" {
		t.Errorf("expected success, got %s", payload.Status)
	}
	if len(payload.Rows) != 0 {
		t.Errorf("expected 0 rows, got %d", len(payload.Rows))
	}
	if payload.Summary["row_count"] != 0 {
		t.Errorf("expected row_count 0, got %v", payload.Summary["row_count"])
	}
	if payload.Summary["oldest_xact_age_seconds"] != 0 {
		t.Errorf("expected oldest_xact_age_seconds 0, got %v", payload.Summary["oldest_xact_age_seconds"])
	}
}

func TestNormalize_SkippedProbe(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("long_running_transactions")
	if p == nil {
		t.Fatal("probe not found")
	}

	raw := probe.RawResult{
		ProbeName:  "long_running_transactions",
		Status:     "skipped",
		SkipReason: "prerequisite not met: test",
	}

	payload := normalize.Normalize(p, raw)

	if payload.Status != "skipped" {
		t.Errorf("expected skipped, got %s", payload.Status)
	}
	if payload.SkipReason != "prerequisite not met: test" {
		t.Errorf("unexpected skip_reason: %s", payload.SkipReason)
	}
	if len(payload.Rows) != 0 {
		t.Errorf("expected empty rows for skipped probe")
	}
}

func TestNormalize_FailedProbe(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("long_running_transactions")
	if p == nil {
		t.Fatal("probe not found")
	}

	raw := probe.RawResult{
		ProbeName: "long_running_transactions",
		Status:    "failed",
		Error:     fmt.Errorf("connection reset by peer"),
	}

	payload := normalize.Normalize(p, raw)

	if payload.Status != "failed" {
		t.Errorf("expected failed, got %s", payload.Status)
	}
	if payload.Error == nil {
		t.Fatal("expected error to be set")
	}
	if payload.Error.Message != "connection reset by peer" {
		t.Errorf("unexpected error message: %s", payload.Error.Message)
	}
	if len(payload.Rows) != 0 {
		t.Errorf("expected empty rows for failed probe")
	}
}

func TestNormalize_QueryTruncation(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("long_running_transactions")
	if p == nil {
		t.Fatal("probe not found")
	}

	longQuery := make([]byte, 2000)
	for i := range longQuery {
		longQuery[i] = 'x'
	}

	raw := probe.RawResult{
		ProbeName:  "long_running_transactions",
		Status:     "success",
		DurationMs: 5,
		Rows: []map[string]any{
			{
				"pid":              1,
				"usename":          "test",
				"application_name": "test",
				"state":            "active",
				"xact_age_seconds": 10,
				"query_age_seconds": 5,
				"query":            string(longQuery),
			},
		},
	}

	payload := normalize.Normalize(p, raw)
	query, ok := payload.Rows[0]["query"].(string)
	if !ok {
		t.Fatal("query field not a string")
	}
	if len(query) > 1000 {
		t.Errorf("query not truncated: length %d", len(query))
	}
}
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
cd cli && go test ./internal/normalize/ -v
```

Expected: FAIL — `normalize.Normalize` not defined.

- [ ] **Step 5: Implement normalizer types and generic logic**

`cli/internal/normalize/normalize.go`:
```go
package normalize

import (
	"github.com/dventimisupabase/pg-healthkit/cli/internal/probe"
	"github.com/dventimisupabase/pg-healthkit/cli/internal/registry"
)

const (
	CollectorVersion  = "0.1.0"
	NormalizerVersion = "0.1.0"
	ContractVersion   = "v1"
	MaxQueryLength    = 1000
)

// CanonicalPayload is the normalized output envelope per docs/15_normalizer.md.
type CanonicalPayload struct {
	ProbeName        string            `json:"probe_name"`
	ProbeVersion     string            `json:"probe_version"`
	Status           string            `json:"status"`
	Summary          map[string]any    `json:"summary"`
	Rows             []map[string]any  `json:"rows"`
	SkipReason       string            `json:"skip_reason,omitempty"`
	Error            *ProbeError       `json:"error,omitempty"`
	Metadata         PayloadMetadata   `json:"metadata"`
	ValidationErrors []string          `json:"validation_errors,omitempty"`
}

// ProbeError represents a probe execution error.
type ProbeError struct {
	Message string `json:"message"`
	Code    string `json:"code,omitempty"`
}

// PayloadMetadata contains operational metadata about the collection.
type PayloadMetadata struct {
	DurationMs        int64    `json:"duration_ms"`
	DatabaseName      string   `json:"database_name,omitempty"`
	ServerVersionNum  int      `json:"server_version_num,omitempty"`
	CollectorVersion  string   `json:"collector_version"`
	NormalizerVersion string   `json:"normalizer_version"`
	ContractVersion   string   `json:"contract_version"`
	ProbeHash         string   `json:"probe_hash,omitempty"`
	Warnings          []string `json:"warnings"`
}

// Normalize transforms a RawResult into a CanonicalPayload.
func Normalize(p *registry.Probe, raw probe.RawResult) CanonicalPayload {
	payload := CanonicalPayload{
		ProbeName:    p.Name,
		ProbeVersion: p.Version,
		Status:       raw.Status,
		Rows:         []map[string]any{},
		Summary:      map[string]any{},
		Metadata: PayloadMetadata{
			DurationMs:        raw.DurationMs,
			CollectorVersion:  CollectorVersion,
			NormalizerVersion: NormalizerVersion,
			ContractVersion:   ContractVersion,
			Warnings:          []string{},
		},
	}

	switch raw.Status {
	case "skipped":
		payload.SkipReason = raw.SkipReason
		return payload
	case "failed":
		if raw.Error != nil {
			payload.Error = &ProbeError{Message: raw.Error.Error()}
		}
		return payload
	}

	// Coerce rows
	payload.Rows = coerceRows(raw.Rows)

	// Restructure probes with non-tabular contracts
	switch p.Name {
	case "instance_metadata":
		payload.Rows = restructureInstanceMetadata(payload.Rows)
	}

	// Derive summary (probe-specific)
	payload.Summary = deriveSummary(p.Name, payload.Rows)

	return payload
}

// coerceRows applies generic type coercion to all rows.
func coerceRows(rows []map[string]any) []map[string]any {
	result := make([]map[string]any, len(rows))
	for i, row := range rows {
		coerced := make(map[string]any, len(row))
		for k, v := range row {
			coerced[k] = coerceValue(k, v)
		}
		result[i] = coerced
	}
	return result
}

// coerceValue applies type coercion rules per the normalizer doc.
func coerceValue(key string, v any) any {
	if v == nil {
		return nil
	}

	// Truncate query text
	if key == "query" {
		if s, ok := v.(string); ok && len(s) > MaxQueryLength {
			return s[:MaxQueryLength]
		}
	}

	return v
}
```

- [ ] **Step 6: Implement summary derivation for long_running_transactions**

`cli/internal/normalize/summary.go`:
```go
package normalize

import "strconv"

// deriveSummary dispatches to probe-specific summary logic.
func deriveSummary(probeName string, rows []map[string]any) map[string]any {
	switch probeName {
	case "long_running_transactions":
		return summarizeLongRunningTransactions(rows)
	default:
		return map[string]any{"row_count": len(rows)}
	}
}

func summarizeLongRunningTransactions(rows []map[string]any) map[string]any {
	summary := map[string]any{
		"row_count":                    len(rows),
		"oldest_xact_age_seconds":      0,
		"oldest_idle_xact_age_seconds": 0,
	}

	for _, row := range rows {
		age := toInt(row["xact_age_seconds"])
		if age > toInt(summary["oldest_xact_age_seconds"]) {
			summary["oldest_xact_age_seconds"] = age
		}

		state, _ := row["state"].(string)
		if state == "idle in transaction" {
			if age > toInt(summary["oldest_idle_xact_age_seconds"]) {
				summary["oldest_idle_xact_age_seconds"] = age
			}
		}
	}

	return summary
}

// toInt converts various numeric types and numeric strings to int.
func toInt(v any) int {
	switch n := v.(type) {
	case int:
		return n
	case int32:
		return int(n)
	case int64:
		return int(n)
	case float64:
		return int(n)
	case float32:
		return int(n)
	case string:
		i, err := strconv.Atoi(n)
		if err != nil {
			return 0
		}
		return i
	default:
		return 0
	}
}
```

- [ ] **Step 7: Run tests to verify they pass**

```bash
cd cli && go test ./internal/normalize/ -v
```

Expected: PASS — all 4 tests green.

- [ ] **Step 8: Commit**

```bash
git add cli/
git commit -m "feat(cli): implement normalizer with long_running_transactions support"
```

---

## Task 5: Validator — Contract Checking

**Files:**
- Create: `cli/internal/validate/validate.go`
- Create: `cli/internal/validate/validate_test.go`

- [ ] **Step 1: Write the failing test**

`cli/internal/validate/validate_test.go`:
```go
package validate_test

import (
	"testing"

	"github.com/dventimisupabase/pg-healthkit/cli/internal/normalize"
	"github.com/dventimisupabase/pg-healthkit/cli/internal/registry"
	"github.com/dventimisupabase/pg-healthkit/cli/internal/validate"
)

func TestValidate_ValidPayload(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("long_running_transactions")
	if p == nil {
		t.Fatal("probe not found")
	}

	payload := normalize.CanonicalPayload{
		ProbeName:    "long_running_transactions",
		ProbeVersion: "2026-03-20",
		Status:       "success",
		Summary: map[string]any{
			"row_count":                    3,
			"oldest_xact_age_seconds":      120,
			"oldest_idle_xact_age_seconds": 300,
		},
		Rows: []map[string]any{
			{
				"pid":              12345,
				"usename":          "app_user",
				"application_name": "myapp",
				"state":            "active",
				"xact_age_seconds": 120,
				"query_age_seconds": 45,
			},
		},
	}

	errs := validate.Validate(p, payload)
	if len(errs) != 0 {
		for _, e := range errs {
			t.Errorf("unexpected validation error: %s", e.Message)
		}
	}
}

func TestValidate_MissingSummaryField(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("long_running_transactions")
	if p == nil {
		t.Fatal("probe not found")
	}

	payload := normalize.CanonicalPayload{
		ProbeName: "long_running_transactions",
		Status:    "success",
		Summary:   map[string]any{
			"row_count": 1,
			// missing oldest_xact_age_seconds and oldest_idle_xact_age_seconds
		},
		Rows: []map[string]any{
			{
				"pid":              1,
				"usename":          "test",
				"application_name": "test",
				"state":            "active",
				"xact_age_seconds": 10,
				"query_age_seconds": 5,
			},
		},
	}

	errs := validate.Validate(p, payload)
	if len(errs) == 0 {
		t.Error("expected validation errors for missing summary fields")
	}
}

func TestValidate_SkippedProbe(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("long_running_transactions")
	if p == nil {
		t.Fatal("probe not found")
	}

	payload := normalize.CanonicalPayload{
		ProbeName:  "long_running_transactions",
		Status:     "skipped",
		SkipReason: "test",
		Summary:    map[string]any{},
		Rows:       []map[string]any{},
	}

	errs := validate.Validate(p, payload)
	if len(errs) != 0 {
		t.Error("skipped probes should not produce validation errors")
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd cli && go test ./internal/validate/ -v
```

Expected: FAIL — `validate.Validate` not defined.

- [ ] **Step 3: Implement validator**

`cli/internal/validate/validate.go`:
```go
package validate

import (
	"fmt"

	"gopkg.in/yaml.v3"

	"github.com/dventimisupabase/pg-healthkit/cli/internal/normalize"
	"github.com/dventimisupabase/pg-healthkit/cli/internal/registry"
)

// ValidationError represents a single validation failure.
type ValidationError struct {
	Field    string `json:"field"`
	Expected string `json:"expected"`
	Actual   string `json:"actual"`
	Message  string `json:"message"`
}

// Validate checks a canonical payload against the probe's contract.
func Validate(p *registry.Probe, payload normalize.CanonicalPayload) []ValidationError {
	// Don't validate skipped or failed probes
	if payload.Status != "success" {
		return nil
	}

	var errs []ValidationError

	// Decode the payload_contract YAML node into a usable map
	contract := decodeContract(p.PayloadContract)
	if contract == nil {
		return []ValidationError{{
			Field:   "payload_contract",
			Message: "could not decode payload contract from registry",
		}}
	}

	// Check summary fields from the contract
	errs = append(errs, validateSummaryFields(contract, payload.Summary)...)

	// Check required row fields if rows are present
	if len(payload.Rows) > 0 {
		errs = append(errs, validateRowFields(contract, payload.Rows[0])...)
	}

	return errs
}

func decodeContract(node yaml.Node) map[string]any {
	var result map[string]any
	if err := node.Decode(&result); err != nil {
		return nil
	}
	return result
}

func validateSummaryFields(contract map[string]any, summary map[string]any) []ValidationError {
	var errs []ValidationError

	props, ok := contract["properties"].(map[string]any)
	if !ok {
		return errs
	}

	summarySpec, ok := props["summary"].(map[string]any)
	if !ok {
		return errs
	}

	required, _ := summarySpec["required"].([]any)
	for _, r := range required {
		fieldName, _ := r.(string)
		if fieldName == "" {
			continue
		}
		if _, exists := summary[fieldName]; !exists {
			errs = append(errs, ValidationError{
				Field:    "summary." + fieldName,
				Expected: "present",
				Actual:   "missing",
				Message:  fmt.Sprintf("required summary field %q is missing", fieldName),
			})
		}
	}

	return errs
}

func validateRowFields(contract map[string]any, row map[string]any) []ValidationError {
	var errs []ValidationError

	props, ok := contract["properties"].(map[string]any)
	if !ok {
		return errs
	}

	rowsSpec, ok := props["rows"].(map[string]any)
	if !ok {
		return errs
	}

	items, ok := rowsSpec["items"].(map[string]any)
	if !ok {
		return errs
	}

	required, _ := items["required"].([]any)
	for _, r := range required {
		fieldName, _ := r.(string)
		if fieldName == "" {
			continue
		}
		if _, exists := row[fieldName]; !exists {
			errs = append(errs, ValidationError{
				Field:    "rows[]." + fieldName,
				Expected: "present",
				Actual:   "missing",
				Message:  fmt.Sprintf("required row field %q is missing", fieldName),
			})
		}
	}

	return errs
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd cli && go test ./internal/validate/ -v
```

Expected: PASS — all 3 tests green.

- [ ] **Step 5: Commit**

```bash
git add cli/
git commit -m "feat(cli): implement contract validator for canonical payloads"
```

---

## Task 6: Wire It Together — main.go

**Files:**
- Modify: `cli/cmd/healthkit/main.go`

- [ ] **Step 1: Implement main.go with flags and orchestration**

`cli/cmd/healthkit/main.go`:
```go
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/dventimisupabase/pg-healthkit/cli/internal/normalize"
	"github.com/dventimisupabase/pg-healthkit/cli/internal/probe"
	"github.com/dventimisupabase/pg-healthkit/cli/internal/registry"
	"github.com/dventimisupabase/pg-healthkit/cli/internal/validate"
)

func main() {
	dsn := flag.String("dsn", "", "PostgreSQL connection string (or set DATABASE_URL)")
	profile := flag.String("profile", "default", "Assessment profile")
	probeNames := flag.String("probes", "", "Comma-separated probe names (default: all for profile)")
	probesDir := flag.String("probes-dir", "../probes", "Path to SQL probe files")
	registryPath := flag.String("registry", "../contracts/probe_registry.yaml", "Path to probe_registry.yaml")
	timeout := flag.Duration("timeout", 30*time.Second, "Per-probe execution timeout")
	flag.Parse()

	if *dsn == "" {
		*dsn = os.Getenv("DATABASE_URL")
	}
	if *dsn == "" {
		fmt.Fprintln(os.Stderr, "error: --dsn or DATABASE_URL required")
		os.Exit(1)
	}

	// Load registry
	reg, err := registry.Load(*registryPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error loading registry: %v\n", err)
		os.Exit(1)
	}

	// Filter probes
	probes := reg.FilterByProfile(*profile)
	if *probeNames != "" {
		names := strings.Split(*probeNames, ",")
		var filtered []registry.Probe
		for _, name := range names {
			name = strings.TrimSpace(name)
			p := reg.FindProbe(name)
			if p == nil {
				fmt.Fprintf(os.Stderr, "warning: probe %q not found in registry\n", name)
				continue
			}
			filtered = append(filtered, *p)
		}
		probes = filtered
	}

	// Connect
	runner, err := probe.NewRunner(*dsn, *probesDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error connecting to database: %v\n", err)
		os.Exit(1)
	}
	defer runner.Close()

	// Run prerequisite probes first (instance_metadata, extensions_inventory)
	// and cache their results so they aren't run twice in the main loop.
	var extensionNames []string
	prerunResults := map[string]probe.RawResult{}

	// extensions_inventory is the authoritative source for installed extensions
	extProbe := reg.FindProbe("extensions_inventory")
	if extProbe != nil {
		ctx, cancel := context.WithTimeout(context.Background(), *timeout)
		extResult := runner.Run(ctx, extProbe)
		cancel()
		prerunResults["extensions_inventory"] = extResult
		if extResult.Status == "success" {
			for _, row := range extResult.Rows {
				if name, ok := row["extname"].(string); ok {
					extensionNames = append(extensionNames, name)
				}
			}
		}
	}

	// Also pre-run instance_metadata (needed by many probes, and runs first by convention)
	imProbe := reg.FindProbe("instance_metadata")
	if imProbe != nil {
		ctx, cancel := context.WithTimeout(context.Background(), *timeout)
		imResult := runner.Run(ctx, imProbe)
		cancel()
		prerunResults["instance_metadata"] = imResult
	}

	// Run all probes, reusing pre-run results where available
	var results []normalize.CanonicalPayload
	for i := range probes {
		p := &probes[i]

		var raw probe.RawResult
		if cached, ok := prerunResults[p.Name]; ok {
			raw = cached
		} else {
			ctx, cancel := context.WithTimeout(context.Background(), *timeout)
			raw = runner.RunWithPrereqs(ctx, p, extensionNames)
			cancel()
		}

		payload := normalize.Normalize(p, raw)

		// Validate
		validationErrs := validate.Validate(p, payload)
		for _, ve := range validationErrs {
			payload.ValidationErrors = append(payload.ValidationErrors, ve.Message)
		}

		results = append(results, payload)
	}

	// Output JSON
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(results); err != nil {
		fmt.Fprintf(os.Stderr, "error encoding output: %v\n", err)
		os.Exit(1)
	}
}
```

- [ ] **Step 2: Verify build**

```bash
cd cli && go build ./cmd/healthkit/
```

Expected: clean build.

- [ ] **Step 3: Run all tests**

```bash
cd cli && go test ./...
```

Expected: all unit tests pass.

- [ ] **Step 4: Commit**

```bash
git add cli/
git commit -m "feat(cli): wire up main.go with flags and orchestration"
```

---

## Task 7: Add instance_metadata and connection_pressure Normalizers

**Files:**
- Modify: `cli/internal/normalize/summary.go`
- Create: `cli/testdata/raw/instance_metadata.json`
- Create: `cli/testdata/canonical/instance_metadata.json`
- Create: `cli/testdata/raw/connection_pressure.json`
- Create: `cli/testdata/canonical/connection_pressure.json`
- Modify: `cli/internal/normalize/normalize_test.go`

- [ ] **Step 1: Create instance_metadata raw fixture**

`cli/testdata/raw/instance_metadata.json`:
```json
{
  "probe_name": "instance_metadata",
  "status": "success",
  "duration_ms": 8,
  "rows": [
    {
      "db": "postgres",
      "version": "PostgreSQL 17.4 on x86_64-pc-linux-gnu",
      "server_version_num": 170004,
      "is_replica": false,
      "max_connections": "100",
      "shared_buffers": "128MB",
      "work_mem": "4MB",
      "maintenance_work_mem": "64MB",
      "effective_cache_size": "4GB",
      "max_wal_size": "1GB",
      "checkpoint_timeout": "300",
      "autovacuum": "on",
      "random_page_cost": "4",
      "log_min_duration_statement": "-1",
      "track_io_timing": "on",
      "shared_preload_libraries": "pg_stat_statements"
    }
  ]
}
```

- [ ] **Step 2: Create connection_pressure raw fixture**

`cli/testdata/raw/connection_pressure.json`:
```json
{
  "probe_name": "connection_pressure",
  "status": "success",
  "duration_ms": 6,
  "rows": [
    {
      "total_connections": 25,
      "active": 5,
      "idle": 15,
      "idle_in_transaction": 3,
      "max_connections": 100,
      "utilization_pct": 25.00
    }
  ]
}
```

- [ ] **Step 3: Write failing tests for both probes**

Add to `cli/internal/normalize/normalize_test.go`:
```go
func TestNormalize_InstanceMetadata(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("instance_metadata")
	if p == nil {
		t.Fatal("probe not found")
	}

	raw := probe.RawResult{
		ProbeName:  "instance_metadata",
		Status:     "success",
		DurationMs: 8,
		Rows: []map[string]any{
			{
				"db":                           "postgres",
				"version":                      "PostgreSQL 17.4 on x86_64-pc-linux-gnu",
				"server_version_num":           170004,
				"is_replica":                   false,
				"max_connections":              "100",
				"shared_buffers":               "128MB",
				"work_mem":                     "4MB",
				"maintenance_work_mem":         "64MB",
				"effective_cache_size":         "4GB",
				"max_wal_size":                 "1GB",
				"checkpoint_timeout":           "300",
				"autovacuum":                   "on",
				"random_page_cost":             "4",
				"log_min_duration_statement":   "-1",
				"track_io_timing":              "on",
				"shared_preload_libraries":     "pg_stat_statements",
			},
		},
	}

	payload := normalize.Normalize(p, raw)

	if payload.Summary["track_io_timing"] != "on" {
		t.Errorf("expected track_io_timing 'on', got %v", payload.Summary["track_io_timing"])
	}
	if payload.Summary["log_min_duration_statement"] != -1 {
		t.Errorf("expected log_min_duration_statement -1, got %v", payload.Summary["log_min_duration_statement"])
	}
	if payload.Summary["random_page_cost"] != "4" {
		t.Errorf("expected random_page_cost '4', got %v", payload.Summary["random_page_cost"])
	}
}

func TestNormalize_ConnectionPressure(t *testing.T) {
	reg, err := registry.Load("../../contracts/probe_registry.yaml")
	if err != nil {
		t.Fatalf("Load registry: %v", err)
	}

	p := reg.FindProbe("connection_pressure")
	if p == nil {
		t.Fatal("probe not found")
	}

	raw := probe.RawResult{
		ProbeName:  "connection_pressure",
		Status:     "success",
		DurationMs: 6,
		Rows: []map[string]any{
			{
				"total_connections":    25,
				"active":              5,
				"idle":                15,
				"idle_in_transaction": 3,
				"max_connections":     100,
				"utilization_pct":     25.00,
			},
		},
	}

	payload := normalize.Normalize(p, raw)

	if payload.Summary["total_connections"] != 25 {
		t.Errorf("expected total_connections 25, got %v", payload.Summary["total_connections"])
	}
	if payload.Summary["utilization_pct"] != 25.0 {
		t.Errorf("expected utilization_pct 25.0, got %v", payload.Summary["utilization_pct"])
	}
	if payload.Summary["idle_in_transaction"] != 3 {
		t.Errorf("expected idle_in_transaction 3, got %v", payload.Summary["idle_in_transaction"])
	}
}
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
cd cli && go test ./internal/normalize/ -v -run "InstanceMetadata|ConnectionPressure"
```

Expected: FAIL — summary derivation returns generic `row_count` only.

- [ ] **Step 5: Add summary derivation functions**

Add to `cli/internal/normalize/summary.go` in the `deriveSummary` switch:
```go
case "instance_metadata":
    return summarizeInstanceMetadata(rows)
case "connection_pressure":
    return summarizeConnectionPressure(rows)
```

Add functions:
```go
func summarizeInstanceMetadata(rows []map[string]any) map[string]any {
	summary := map[string]any{
		"track_io_timing":              nil,
		"log_min_duration_statement":   nil,
		"random_page_cost":             nil,
		"shared_preload_libraries":     nil,
	}

	if len(rows) == 0 {
		return summary
	}

	row := rows[0]
	if v, ok := row["track_io_timing"]; ok {
		summary["track_io_timing"] = v
	}
	if v, ok := row["log_min_duration_statement"]; ok {
		summary["log_min_duration_statement"] = toInt(v)
	}
	if v, ok := row["random_page_cost"]; ok {
		summary["random_page_cost"] = v
	}
	if v, ok := row["shared_preload_libraries"]; ok {
		summary["shared_preload_libraries"] = v
	}

	return summary
}

// restructureInstanceMetadata converts the flat SQL row into the nested
// contract shape: {postgres_version, server_version_num, is_replica, settings: {...}, summary: {...}}.
// Called from Normalize() before summary derivation for this probe.
func restructureInstanceMetadata(rows []map[string]any) []map[string]any {
	if len(rows) == 0 {
		return rows
	}
	row := rows[0]

	settings := map[string]any{}
	settingsKeys := []string{
		"max_connections", "shared_buffers", "work_mem", "maintenance_work_mem",
		"effective_cache_size", "max_wal_size", "checkpoint_timeout", "autovacuum",
		"random_page_cost", "log_min_duration_statement", "track_io_timing",
		"shared_preload_libraries",
	}
	for _, k := range settingsKeys {
		settings[k] = row[k]
	}

	structured := map[string]any{
		"postgres_version":    row["version"],
		"server_version_num": row["server_version_num"],
		"is_replica":         row["is_replica"],
		"db":                 row["db"],
		"settings":           settings,
	}

	return []map[string]any{structured}
}

func summarizeConnectionPressure(rows []map[string]any) map[string]any {
	summary := map[string]any{
		"total_connections":    0,
		"active":              0,
		"idle":                0,
		"idle_in_transaction": 0,
		"max_connections":     0,
		"utilization_pct":     0.0,
	}

	if len(rows) == 0 {
		return summary
	}

	row := rows[0]
	active := toInt(row["active"])
	idle := toInt(row["idle"])
	idleInTx := toInt(row["idle_in_transaction"])

	summary["total_connections"] = toInt(row["total_connections"])
	summary["active"] = active
	summary["idle"] = idle
	summary["idle_in_transaction"] = idleInTx
	summary["max_connections"] = toInt(row["max_connections"])

	if v, ok := row["utilization_pct"].(float64); ok {
		summary["utilization_pct"] = v
	} else {
		maxConn := toInt(row["max_connections"])
		totalConn := toInt(row["total_connections"])
		if maxConn > 0 {
			summary["utilization_pct"] = float64(totalConn) / float64(maxConn) * 100
		}
	}

	return summary
}

// synthesizeConnectionPressureStates builds the states array from summary counts
// per docs/15_normalizer.md.
func synthesizeConnectionPressureStates(rows []map[string]any) []map[string]any {
	if len(rows) == 0 {
		return []map[string]any{}
	}
	row := rows[0]
	return []map[string]any{
		{"state": "active", "count": toInt(row["active"])},
		{"state": "idle", "count": toInt(row["idle"])},
		{"state": "idle in transaction", "count": toInt(row["idle_in_transaction"])},
	}
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd cli && go test ./internal/normalize/ -v
```

Expected: PASS — all tests green.

- [ ] **Step 7: Commit**

```bash
git add cli/
git commit -m "feat(cli): add instance_metadata and connection_pressure normalizers"
```

---

## Task 8: End-to-End Smoke Test

**Files:**
- No new files — this is a manual verification task

- [ ] **Step 1: Build the binary**

```bash
cd cli && go build -o healthkit ./cmd/healthkit/
```

- [ ] **Step 2: Run all unit tests**

```bash
cd cli && go test ./... -v
```

Expected: all tests pass.

- [ ] **Step 3: Run against a real database (if available)**

```bash
cd cli && ./healthkit --dsn "postgres://localhost:5432/postgres" --profile default --probes "instance_metadata,long_running_transactions,connection_pressure" 2>/dev/null | head -50
```

Expected: JSON array with 3 probe payloads. If no database is available, skip this step.

- [ ] **Step 4: Verify skipped probe behavior (if pg_stat_statements probes are in the run)**

```bash
cd cli && ./healthkit --dsn "postgres://localhost:5432/postgres" --profile default 2>/dev/null | python3 -c "import sys,json; data=json.load(sys.stdin); [print(f'{d[\"probe_name\"]}: {d[\"status\"]}') for d in data]"
```

Expected: probes requiring pg_stat_statements show `skipped` if the extension is not loaded.

- [ ] **Step 5: Commit (add .gitignore for binary)**

```bash
echo "healthkit" >> cli/.gitignore
git add cli/.gitignore
git commit -m "chore(cli): add binary to gitignore"
```

- [ ] **Step 6: Push branch**

```bash
git push -u origin trial_01
```
