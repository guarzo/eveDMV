# Comprehensive Code Review Plan for EVE DMV

## Purpose and Scope

This document defines a **reusable code review methodology** for the EVE DMV codebase. The review process produces markdown documentation and analysis reports—not direct code changes.

### What This Plan Produces

Each phase of this review generates **markdown deliverables** that:
- Document findings with specific file paths and line numbers
- Categorize issues by severity and effort
- Provide actionable recommendations for future implementation
- Create a prioritized backlog of technical debt

### What This Plan Does NOT Do

- This plan does **not** make code changes directly
- This plan does **not** implement fixes
- This plan does **not** refactor modules

The separation between **analysis** (this plan) and **implementation** (future work) ensures thorough documentation and allows stakeholders to review and prioritize findings before any code is modified.

---

## Baseline Metrics Template

Before starting the review, capture current metrics to establish a baseline. These values should be recorded in the final summary document.

### Codebase Metrics (To Be Captured)

| Metric | Command | Value | Target | Gap |
|--------|---------|-------|--------|-----|
| Source Files | `find lib -name "*.ex" \| wc -l` | ___ | - | - |
| Test Files | `find test -name "*.exs" \| wc -l` | ___ | 1:3 ratio | - |
| Ash Resources | `grep -rln "use Ash.Resource" lib/ \| wc -l` | ___ | - | - |
| @spec Annotations | `grep -rn "@spec" lib/ \| wc -l` | ___ | 80%+ coverage | - |
| @impl true Usage | `grep -rn "@impl true" lib/ \| wc -l` | ___ | All callbacks | - |
| @moduledoc false | `grep -rln "@moduledoc false" lib/ \| wc -l` | ___ | <10 | - |
| GenServers | `grep -rln "use GenServer" lib/ \| wc -l` | ___ | - | - |
| Raw SQL Queries | `grep -rln "Ecto.Adapters.SQL.query" lib/ \| wc -l` | ___ | <20 | - |
| Dialyzer Errors | `mix dialyzer 2>&1 \| grep "Total errors" ` | ___ | 0 | - |
| Files > 500 lines | `wc -l lib/**/*.ex \| awk '$1>500' \| wc -l` | ___ | <50 | - |
| Bounded Contexts | `ls -d lib/eve_dmv/contexts/*/ \| wc -l` | ___ | 10-12 | - |
| Feature Flags | `grep -rn "feature_enabled?" lib/ \| wc -l` | ___ | 2-3 | - |
| @deprecated Code | `grep -rn "@deprecated" lib/ \| wc -l` | ___ | 0 | - |
| Disabled/Unused Files | `find lib -name "*.disabled" -o -name "*.unused" \| wc -l` | ___ | 0 | - |

---

## Deliverables Overview

Each phase produces markdown documents saved to `docs/review/`. The complete review generates:

| Phase | Deliverable | Description |
|-------|-------------|-------------|
| 1 | `docs/review/01_idiomatic_elixir_audit.md` | @impl, @spec, pattern matching, error handling |
| 2 | `docs/review/02_ash_framework_audit.md` | Resource definitions, raw SQL, actions, domains |
| 3 | `docs/review/03_context_architecture_audit.md` | Context overlap, large files, API modules |
| 4 | `docs/review/04_type_safety_audit.md` | Dialyzer errors, type specifications |
| 5 | `docs/review/05_test_coverage_audit.md` | Coverage gaps, missing tests, quality |
| 6 | `docs/review/06_documentation_audit.md` | @moduledoc, @doc, stale comments |
| 7 | `docs/review/07_performance_audit.md` | GenServer supervision, N+1 queries, caching |
| 8 | `docs/review/08_transitory_code_audit.md` | Feature flags, deprecated code, legacy adapters |
| Final | `docs/review/CODE_REVIEW_SUMMARY.md` | Consolidated findings, prioritized backlog |

### Standard Finding Template

Each finding in a deliverable should follow this structure:

```markdown
#### Finding X.Y.Z: [Brief Title]

- **File:** `path/to/file.ex`
- **Line(s):** X-Y
- **Severity:** Critical | High | Medium | Low
- **Effort:** Small (<1hr) | Medium (1-4hr) | Large (>4hr)
- **Description:** What the issue is and why it matters
- **Current Code:**
  ```elixir
  # Problematic pattern
  ```
- **Recommendation:**
  ```elixir
  # Recommended pattern
  ```
```

---

## Phase 1: Idiomatic Elixir Patterns Audit

**Deliverable:** `docs/review/01_idiomatic_elixir_audit.md`

**Objective:** Identify deviations from idiomatic Elixir patterns and document them with specific file locations, code examples, and remediation recommendations.

### 1.1 Callback Implementation Annotations (@impl true)

**What to Look For:**
- GenServer modules without `@impl true` on callbacks
- LiveView modules without `@impl true` on lifecycle functions
- Broadway modules without `@impl true` on message handlers
- Any module implementing a behaviour without annotating callbacks

**Why It Matters:**
- Compiler can't warn about misspelled callbacks without @impl
- No indication whether a function is a callback vs regular function
- Makes refactoring dangerous when behaviours change

**Analysis Commands:**

```bash
# Find all GenServer modules
grep -rln "use GenServer" lib/ --include="*.ex"

# Find GenServer modules missing @impl
grep -rln "use GenServer" lib/ | xargs -I{} sh -c \
  'if ! grep -q "@impl true" "{}"; then echo "MISSING @impl: {}"; fi'

# Find LiveView modules missing @impl
grep -rln "use.*LiveView" lib/ | xargs -I{} sh -c \
  'if ! grep -q "@impl true" "{}"; then echo "MISSING @impl: {}"; fi'

# Find Broadway modules missing @impl
grep -rln "use Broadway" lib/ | xargs -I{} sh -c \
  'if ! grep -q "@impl true" "{}"; then echo "MISSING @impl: {}"; fi'

# Count callbacks per file for effort estimation
for f in $(grep -rln "use GenServer" lib/); do
  count=$(grep -c "def handle_\|def init\|def terminate\|def code_change" "$f" 2>/dev/null || echo 0)
  echo "$count callbacks: $f"
done | sort -rn | head -20
```

**Document Output Requirements:**

For each module missing @impl, document:

| Field | Content |
|-------|---------|
| File Path | Full path to the module |
| Behaviour Type | GenServer, LiveView, Broadway, Custom |
| Missing Callbacks | List of callback functions needing @impl |
| Callback Count | Number of callbacks to annotate |
| Effort Estimate | Small (<5), Medium (5-15), Large (>15) |

**Callbacks to Check by Behaviour:**

| Behaviour | Callbacks Requiring @impl |
|-----------|---------------------------|
| GenServer | `init/1`, `handle_call/3`, `handle_cast/2`, `handle_info/2`, `handle_continue/2`, `terminate/2`, `code_change/3` |
| LiveView | `mount/3`, `render/1`, `handle_event/3`, `handle_info/2`, `handle_params/3`, `handle_async/3` |
| Broadway | `handle_message/3`, `handle_batch/4`, `handle_failed/3` |
| Plug | `init/1`, `call/2` |
| Phoenix.Controller | `action/2` (if overridden) |

---

### 1.2 Type Specifications (@spec) Coverage

**What to Look For:**
- Public functions without @spec annotations
- @spec that don't match actual return values
- Missing type definitions for common patterns
- Inconsistent use of result tuples

**Analysis Commands:**

```bash
# Count specs vs public functions per module
for f in $(find lib -name "*.ex"); do
  specs=$(grep -c "@spec" "$f" 2>/dev/null || echo 0)
  funcs=$(grep -c "^\s*def [a-z]" "$f" 2>/dev/null || echo 0)
  if [ "$funcs" -gt 0 ]; then
    pct=$((specs * 100 / funcs))
    echo "$pct% ($specs/$funcs): $f"
  fi
done | sort -n | head -30

# Find public functions missing @spec in API modules
for api in lib/eve_dmv/contexts/*/api.ex; do
  echo "=== $api ==="
  grep -n "^\s*def [a-z]" "$api" | while read line; do
    linenum=$(echo "$line" | cut -d: -f1)
    prevline=$((linenum - 1))
    if ! sed -n "${prevline}p" "$api" | grep -q "@spec"; then
      echo "  MISSING: $line"
    fi
  done
done
```

**Document Output Requirements:**

For each module with incomplete spec coverage:

| Field | Content |
|-------|---------|
| File Path | Full path |
| Coverage | X specs / Y functions (Z%) |
| Priority | Critical (API), High (Platform), Medium (Domain), Low (Internal) |
| Missing Specs | List of function signatures needing @spec |

**Priority Tiers:**

| Tier | Module Type | Target Coverage |
|------|-------------|-----------------|
| 1 | Context API modules (`*/api.ex`) | 100% |
| 2 | Platform modules (`platform/`) | 100% |
| 3 | Domain services (`*/domain/`) | 80% |
| 4 | Internal helpers | 50% |

---

### 1.3 Pattern Matching Best Practices

**What to Look For:**

| Anti-Pattern | Better Pattern |
|--------------|----------------|
| `if value != nil` | Pattern match or `case` |
| `Map.get(map, :key)` when key is required | `map.key` or `%{key: value} = map` |
| Nested `case` statements | `with` expressions |
| Single-expression pipes `x \|> f()` | Direct call `f(x)` |
| String concatenation `a <> b <> c` | Interpolation `"#{a}#{b}#{c}"` or iodata |

**Analysis Commands:**

```bash
# Find nil checks that could be pattern matches
grep -rn "!= nil\|== nil" lib/ --include="*.ex" | head -30

# Find nested case statements
grep -rn "case.*do" lib/ --include="*.ex" -A 10 | grep -E "^\s+case" | head -20

# Find single-expression pipes
grep -rn "|> [a-z_]*(" lib/ --include="*.ex" | \
  grep -v "|>.*|>" | head -20

# Find potential Map.get misuse on required keys
grep -rn "Map.get.*,.*)" lib/ --include="*.ex" | \
  grep -v "Map.get.*,.*," | head -20
```

**Document Output Requirements:**

Group findings by anti-pattern type with examples from the codebase.

---

### 1.4 Error Handling Consistency

**What to Look For:**
- Inconsistent error tuple formats (`{:error, atom}` vs `{:error, string}`)
- Swallowed errors (catch-all patterns that hide issues)
- Missing error cases in `with` expressions
- Generic `:error` atoms without context

**Analysis Commands:**

```bash
# Find error tuple patterns
grep -rn "{:error," lib/ --include="*.ex" | \
  sed 's/.*{:error, \([^}]*\)}.*/\1/' | sort | uniq -c | sort -rn | head -20

# Find catch-all error handlers
grep -rn "_ -> :error\|_ -> {:error" lib/ --include="*.ex" | head -20

# Find with expressions without else clauses
grep -rB5 "with.*<-" lib/ --include="*.ex" | grep -v "else" | head -20
```

---

### 1.5 Elixir Idiom Checklist

For each file reviewed, check:

- [ ] All behaviour callbacks have `@impl true`
- [ ] All public functions have `@spec`
- [ ] No nil checks where pattern matching works
- [ ] No nested case statements (use `with`)
- [ ] No single-expression pipes
- [ ] Consistent error tuple format
- [ ] Proper use of `with` for happy path
- [ ] Guards used appropriately
- [ ] No mutable-style patterns

---

## Phase 2: Ash Framework Optimization

**Deliverable:** `docs/review/02_ash_framework_audit.md`

**Objective:** Audit all Ash resources for completeness and identify opportunities to migrate raw SQL to Ash patterns.

### 2.1 Resource Definition Audit

**What to Look For:**
- Resources missing required DSL sections
- Resources using only default actions
- Missing validations, calculations, or aggregates
- Relationships not properly defined
- Resources not registered in a domain

**Analysis Commands:**

```bash
# List all Ash resources
grep -rln "use Ash.Resource" lib/ --include="*.ex"

# Check each resource for required sections
for f in $(grep -rln "use Ash.Resource" lib/); do
  echo "=== $f ==="
  echo -n "  domain: "; grep -q "domain:" "$f" && echo "YES" || echo "NO"
  echo -n "  actions: "; grep -q "actions do" "$f" && echo "YES" || echo "NO"
  echo -n "  attributes: "; grep -q "attributes do" "$f" && echo "YES" || echo "NO"
  echo -n "  relationships: "; grep -q "relationships do" "$f" && echo "YES" || echo "NO"
  echo -n "  validations: "; grep -q "validations do" "$f" && echo "YES" || echo "NO"
  echo -n "  calculations: "; grep -q "calculations do" "$f" && echo "YES" || echo "NO"
  echo -n "  aggregates: "; grep -q "aggregates do" "$f" && echo "YES" || echo "NO"
  echo -n "  identities: "; grep -q "identities do" "$f" && echo "YES" || echo "NO"
done

# Find resources using only default actions
grep -rln "defaults \[:read" lib/ --include="*.ex" | while read f; do
  if ! grep -q "create :\|update :\|read :" "$f"; then
    echo "DEFAULTS ONLY: $f"
  fi
done
```

**Resource Completeness Checklist:**

| Section | Required? | Purpose |
|---------|-----------|---------|
| `domain` | Yes | Associates resource with a domain |
| `postgres` | Yes (if persisted) | Table and repo configuration |
| `actions` | Yes | CRUD and custom operations |
| `attributes` | Yes | Data fields with types |
| `relationships` | If applicable | Associations to other resources |
| `identities` | If applicable | Unique constraints |
| `validations` | Recommended | Business rule enforcement |
| `calculations` | Recommended | Computed values |
| `aggregates` | Recommended | Summary statistics |

---

### 2.2 Raw SQL Migration Inventory

**What to Look For:**
- `Ecto.Adapters.SQL.query/3` calls that could use Ash
- Complex queries that could become Ash read actions
- Aggregations that should be Ash aggregates
- Joins that should be relationships

**Analysis Commands:**

```bash
# Find all raw SQL usage
grep -rn "Ecto.Adapters.SQL.query" lib/ --include="*.ex"

# Categorize by query type
grep -rh "Ecto.Adapters.SQL.query" lib/ --include="*.ex" -A 3 | \
  grep -i "SELECT\|INSERT\|UPDATE\|DELETE" | \
  sed 's/.*\(SELECT\|INSERT\|UPDATE\|DELETE\).*/\1/' | \
  sort | uniq -c

# Find files with most raw SQL
grep -rln "Ecto.Adapters.SQL.query" lib/ --include="*.ex" | \
  xargs -I{} sh -c 'echo "$(grep -c "Ecto.Adapters.SQL.query" {}) {}"' | \
  sort -rn
```

**Migration Categories:**

| Category | Ash Replacement | Effort |
|----------|-----------------|--------|
| Simple SELECT | Read action with filters | Low |
| COUNT/SUM/AVG | Ash aggregate | Low |
| JOIN queries | Relationships + load | Medium |
| Complex CTEs | Keep as SQL or fragment | High |
| Window functions | Keep as SQL | High |

---

### 2.3 Action Refactoring Opportunities

**What to Look For:**
- Business logic in API modules that should be Ash actions
- Service functions that wrap simple Ash operations
- Validation logic outside of resources
- Computed values not defined as calculations

**Analysis Commands:**

```bash
# Find large API modules (logic should move to resources)
wc -l lib/eve_dmv/contexts/*/api.ex | sort -rn | head -10

# Find Ash.create/read/update calls wrapped in functions
grep -rn "Ash\.create\|Ash\.read\|Ash\.update" lib/eve_dmv/contexts/*/api.ex | head -30

# Find validation logic outside resources
grep -rn "validate\|is_valid\|check_" lib/eve_dmv/contexts/ --include="*.ex" | \
  grep -v "resources/" | head -20
```

---

### 2.4 Domain Consolidation

**What to Look For:**
- Duplicate domains serving similar purposes
- Resources registered in wrong domains
- Domains with only 1-2 resources

**Analysis Commands:**

```bash
# List all domains
grep -rln "use Ash.Domain" lib/ --include="*.ex"

# Count resources per domain
for domain in $(grep -rln "use Ash.Domain" lib/); do
  count=$(grep -c "resource " "$domain" 2>/dev/null || echo 0)
  echo "$count resources: $domain"
done | sort -rn
```

---

## Phase 3: Context Architecture Review

**Deliverable:** `docs/review/03_context_architecture_audit.md`

**Objective:** Analyze bounded contexts for overlap and consolidation opportunities, inventory large files, and assess API module compliance.

### 3.1 Context Overlap Analysis

**What to Look For:**
- Contexts with similar names (combat vs combat_analysis vs combat_intelligence)
- Cross-context dependencies indicating unclear boundaries
- Shared concepts implemented in multiple contexts
- Contexts with very few files that could merge

**Analysis Commands:**

```bash
# Count files per context
for ctx in lib/eve_dmv/contexts/*/; do
  count=$(find "$ctx" -name "*.ex" | wc -l)
  echo "$count files: $(basename $ctx)"
done | sort -rn

# Find cross-context dependencies
for ctx in lib/eve_dmv/contexts/*/; do
  name=$(basename "$ctx")
  echo "=== $name depends on ==="
  grep -rh "alias EveDmv.Contexts\." "$ctx" 2>/dev/null | \
    grep -v "$name" | sort -u | head -5
done

# Find similar module names across contexts
find lib/eve_dmv/contexts -name "*.ex" -exec basename {} \; | \
  sort | uniq -c | sort -rn | head -20
```

**Context Grouping Analysis:**

Document contexts that might overlap:
- Combat-related contexts
- Corporation-related contexts
- Intelligence-related contexts
- Surveillance-related contexts

For each group, document:
- What distinguishes each context
- Evidence of overlap or duplication
- Consolidation recommendation

---

### 3.2 Large File Decomposition

**What to Look For:**
- Files exceeding 500 lines (need review)
- Files exceeding 1,000 lines (need splitting)
- Files exceeding 2,000 lines (critical priority)

**Analysis Commands:**

```bash
# Find files over 500 lines
find lib -name "*.ex" -exec wc -l {} \; | \
  awk '$1 > 500 {print}' | sort -rn

# Categorize by size
find lib -name "*.ex" -exec wc -l {} \; | awk '
  $1 > 2000 {critical++}
  $1 > 1000 && $1 <= 2000 {high++}
  $1 > 500 && $1 <= 1000 {medium++}
  END {
    print "Critical (>2000):", critical
    print "High (1000-2000):", high
    print "Medium (500-1000):", medium
  }'

# Analyze function count in large files
for f in $(find lib -name "*.ex" -exec sh -c 'test $(wc -l < "$1") -gt 1000 && echo "$1"' _ {} \;); do
  funcs=$(grep -c "^\s*def [a-z]" "$f" 2>/dev/null || echo 0)
  lines=$(wc -l < "$f")
  echo "$lines lines, $funcs functions: $f"
done | sort -rn
```

**Decomposition Recommendations:**

For each large file, recommend:
- Logical groupings of functions
- Suggested module split
- Dependencies to consider

---

### 3.3 API Module Compliance

**What to Look For:**
- API modules with business logic (should delegate)
- API modules exceeding 200 lines
- Missing @doc on public functions
- Inconsistent naming across contexts

**Analysis Commands:**

```bash
# Check API module sizes
wc -l lib/eve_dmv/contexts/*/api.ex | sort -rn

# Find business logic in API modules (should be delegated)
for api in lib/eve_dmv/contexts/*/api.ex; do
  logic=$(grep -c "case \|if \|with " "$api" 2>/dev/null || echo 0)
  if [ "$logic" -gt 5 ]; then
    echo "$logic logic blocks: $api"
  fi
done

# Count delegations vs direct implementations
for api in lib/eve_dmv/contexts/*/api.ex; do
  deleg=$(grep -c "defdelegate" "$api" 2>/dev/null || echo 0)
  direct=$(grep -c "^\s*def [a-z]" "$api" 2>/dev/null || echo 0)
  echo "$(basename $(dirname $api)): $deleg delegated, $direct total"
done
```

**API Module Standards:**

| Metric | Target |
|--------|--------|
| Max lines | 200 |
| Logic blocks | 0 (delegate all) |
| @doc coverage | 100% |
| @spec coverage | 100% |

---

## Phase 4: Type Safety and Dialyzer

**Deliverable:** `docs/review/04_type_safety_audit.md`

**Objective:** Categorize dialyzer errors and create a remediation plan.

### 4.1 Dialyzer Error Analysis

**Analysis Commands:**

```bash
# Run dialyzer and capture output
mix dialyzer 2>&1 | tee /tmp/dialyzer_output.txt

# Count errors by type
grep -E ":\d+:" /tmp/dialyzer_output.txt | \
  sed 's/.*:\([a-z_]*\)$/\1/' | sort | uniq -c | sort -rn

# Find files with most errors
grep -E "lib/.*\.ex:" /tmp/dialyzer_output.txt | \
  cut -d: -f1 | sort | uniq -c | sort -rn | head -20

# Analyze suppression file
cat .dialyzer_ignore.exs | grep -c "~r/"
```

**Error Categories:**

| Error Type | Meaning | Fix Pattern |
|------------|---------|-------------|
| `contract_supertype` | Spec too narrow | Add missing return types |
| `pattern_match_cov` | Impossible pattern | Remove dead code |
| `call_to_missing` | Function doesn't exist | Add missing clause or fix typo |
| `guard_fail` | Guard always fails | Fix guard logic |
| `no_return` | Function never returns | Check for infinite loops |

---

### 4.2 Type Specification Improvements

**What to Look For:**
- Missing custom type definitions
- Inconsistent result tuple types
- Overly broad types (`any()`, `term()`)
- Missing `@type` exports

**Recommendations:**

Create a centralized types module:

```elixir
defmodule EveDmv.Types do
  @type character_id :: pos_integer()
  @type corporation_id :: pos_integer()
  @type result(t) :: {:ok, t} | {:error, error_reason()}
  @type error_reason :: atom() | String.t() | {atom(), term()}
end
```

---

## Phase 5: Test Infrastructure

**Deliverable:** `docs/review/05_test_coverage_audit.md`

**Objective:** Identify modules lacking tests and prioritize test creation.

### 5.1 Coverage Gap Analysis

**Analysis Commands:**

```bash
# Generate coverage report
MIX_ENV=test mix coveralls.html

# Find source files without test files
for src in $(find lib/eve_dmv/contexts -name "*.ex"); do
  test_path=$(echo "$src" | sed 's|lib/|test/|; s|\.ex$|_test.exs|')
  if [ ! -f "$test_path" ]; then
    echo "NO TEST: $src"
  fi
done

# Count test vs source files per context
for dir in lib/eve_dmv/contexts/*/; do
  name=$(basename "$dir")
  src=$(find "$dir" -name "*.ex" | wc -l)
  tst=$(find "test/eve_dmv/contexts/$name" -name "*_test.exs" 2>/dev/null | wc -l)
  echo "$name: $tst tests / $src sources"
done
```

**Priority Matrix:**

| Module Type | Priority | Reason |
|-------------|----------|--------|
| Context API | Critical | Public interface |
| Domain services | High | Business logic |
| Resources | High | Data integrity |
| Infrastructure | Medium | Integration points |
| Helpers | Low | Simple utilities |

---

## Phase 6: Documentation Audit

**Deliverable:** `docs/review/06_documentation_audit.md`

**Objective:** Inventory documentation gaps and stale content.

### 6.1 Module Documentation

**Analysis Commands:**

```bash
# Find modules with @moduledoc false
grep -rln "@moduledoc false" lib/ --include="*.ex"

# Find modules missing @moduledoc entirely
for f in $(find lib -name "*.ex"); do
  if ! grep -q "@moduledoc" "$f"; then
    echo "NO MODULEDOC: $f"
  fi
done

# Find public functions missing @doc
for f in $(find lib/eve_dmv/contexts/*/api.ex); do
  grep -n "^\s*def [a-z]" "$f" | while read line; do
    num=$(echo "$line" | cut -d: -f1)
    prev=$((num - 1))
    if ! sed -n "${prev}p" "$f" | grep -q "@doc"; then
      echo "$f:$num - missing @doc"
    fi
  done
done

# Find stale TODO/FIXME
grep -rn "TODO\|FIXME\|HACK\|XXX" lib/ --include="*.ex"
```

---

## Phase 7: Performance and Architecture

**Deliverable:** `docs/review/07_performance_audit.md`

**Objective:** Audit GenServer supervision, identify N+1 patterns, and evaluate caching.

### 7.1 GenServer Supervision Audit

**Analysis Commands:**

```bash
# List all GenServers
grep -rln "use GenServer" lib/ --include="*.ex"

# Check if each is supervised
for gs in $(grep -rln "use GenServer" lib/); do
  mod=$(grep "defmodule" "$gs" | head -1 | sed 's/defmodule \(.*\) do/\1/')
  if grep -rq "$mod" lib/eve_dmv/application.ex 2>/dev/null; then
    echo "SUPERVISED: $mod"
  else
    echo "ORPHANED?: $mod"
  fi
done

# Analyze supervision tree
grep -A 50 "def start" lib/eve_dmv/application.ex | grep -E "^\s+\{"
```

### 7.2 N+1 Query Detection

**What to Look For:**
- `Ash.load!/2` inside `Enum.map/2`
- Multiple queries in loops
- Missing `:load` option in initial query

**Analysis Commands:**

```bash
# Find potential N+1 patterns
grep -rn "Enum.map.*Ash.load\|Enum.each.*Ash.load" lib/ --include="*.ex"

# Find queries without preloads
grep -rn "Ash.read!" lib/ --include="*.ex" | grep -v "load:"
```

---

## Phase 8: Feature Flags and Transitory Code

**Deliverable:** `docs/review/08_transitory_code_audit.md`

**Objective:** Inventory feature flags, deprecated code, and legacy patterns for cleanup.

### 8.1 Feature Flag Inventory

**Analysis Commands:**

```bash
# Find all feature flag usage
grep -rn "feature_enabled?\|System.get_env.*ENABLE\|System.get_env.*USE_" lib/

# Find query migration flags
grep -rn "use_ash_\|QueryMigration" lib/ --include="*.ex"

# List all environment variable checks
grep -rn "System.get_env" lib/eve_dmv/config/
```

**Document for Each Flag:**
- Flag name and environment variable
- Current default value
- Purpose/migration status
- Code paths affected
- Recommendation (enable/remove/keep)

### 8.2 Deprecated Code

**Analysis Commands:**

```bash
# Find @deprecated annotations
grep -rn "@deprecated" lib/ --include="*.ex"

# Check if deprecated functions are still called
# (run for each deprecated function found)
grep -rn "function_name" lib/ --include="*.ex"
```

### 8.3 Disabled and Unused Files

**Analysis Commands:**

```bash
# Find disabled/unused files
find lib -name "*.disabled" -o -name "*.unused" -o -name "*.bak"

# Check if module is referenced anywhere
# (run for each disabled file)
grep -rn "ModuleName" lib/ --include="*.ex"
```

### 8.4 Fallback Code Audit

**What to Look For:**
- "Legacy" comments indicating old patterns
- Fallback logic for removed features
- Multiple code paths for the same operation

**Analysis Commands:**

```bash
# Find fallback/legacy comments
grep -rn "# [Ff]allback\|# [Ll]egacy\|# [Oo]ld" lib/ --include="*.ex"

# Count by file
grep -rln "# [Ff]allback\|# [Ll]egacy" lib/ | \
  xargs -I{} sh -c 'echo "$(grep -c "# [Ff]allback\|# [Ll]egacy" {}) {}"' | \
  sort -rn | head -20
```

**Fallback Classification:**

| Type | Action |
|------|--------|
| API unavailable fallback | Keep (legitimate) |
| Legacy format support | Review for removal |
| Migration period code | Remove if migration complete |
| Defensive nil handling | Review if still needed |

---

## Execution Process

### Review Phase 1: Initial Analysis

1. Run baseline metrics commands, record in summary
2. Execute Phase 1 (Idiomatic Elixir) analysis commands
3. Execute Phase 4 (Dialyzer) analysis commands
4. Execute Phase 8 (Transitory) deprecated code commands
5. Generate deliverables 01, 04, 08 (partial)

### Review Phase 2: Ash Framework

1. Execute Phase 2 (Ash) analysis commands
2. Execute Phase 8 (Transitory) feature flag commands
3. Generate deliverable 02, update 08

### Review Phase 3: Architecture

1. Execute Phase 3 (Context Architecture) analysis commands
2. Execute Phase 8 (Transitory) legacy adapter commands
3. Generate deliverable 03, update 08

### Review Phase 4: Quality Infrastructure

1. Execute Phase 5 (Test Coverage) analysis commands
2. Execute Phase 6 (Documentation) analysis commands
3. Execute Phase 7 (Performance) analysis commands
4. Generate deliverables 05, 06, 07

### Review Phase 5: Consolidation

1. Compile all findings from phases 1-4
2. Prioritize by severity and effort
3. Generate final summary deliverable

---

## Review Completion Checklist

- [ ] All baseline metrics captured
- [ ] `docs/review/01_idiomatic_elixir_audit.md` complete
- [ ] `docs/review/02_ash_framework_audit.md` complete
- [ ] `docs/review/03_context_architecture_audit.md` complete
- [ ] `docs/review/04_type_safety_audit.md` complete
- [ ] `docs/review/05_test_coverage_audit.md` complete
- [ ] `docs/review/06_documentation_audit.md` complete
- [ ] `docs/review/07_performance_audit.md` complete
- [ ] `docs/review/08_transitory_code_audit.md` complete
- [ ] `docs/review/CODE_REVIEW_SUMMARY.md` complete
- [ ] All findings have severity and effort estimates
- [ ] Recommendations are specific and actionable
- [ ] Priority backlog created

---

## Appendix: Quick Reference Commands

### Counting Commands

```bash
# Source files
find lib -name "*.ex" | wc -l

# Test files
find test -name "*.exs" | wc -l

# Lines of code
find lib -name "*.ex" | xargs wc -l | tail -1

# Ash resources
grep -rln "use Ash.Resource" lib/ | wc -l

# GenServers
grep -rln "use GenServer" lib/ | wc -l
```

### Search Patterns

```bash
# Find module by name
grep -rln "defmodule.*ModuleName" lib/

# Find function calls
grep -rn "function_name(" lib/

# Find all uses of a module
grep -rn "ModuleName\." lib/

# Find file by partial name
find lib -name "*partial*"
```

### Quality Checks

```bash
# Format check
mix format --check-formatted

# Credo
mix credo --strict

# Dialyzer
mix dialyzer

# Tests with coverage
MIX_ENV=test mix coveralls
```
