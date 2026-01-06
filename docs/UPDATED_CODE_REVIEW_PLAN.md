# Comprehensive Code Review Plan for EVE DMV

## Executive Summary

This document provides a systematic, actionable code review plan for the EVE DMV codebase, focusing on idiomatic Elixir practices and maximizing Ash Framework capabilities.

### Codebase Metrics (Current State)

| Metric | Value | Target | Gap Analysis |
|--------|-------|--------|--------------|
| Source Files | 864 | - | - |
| Test Files | 106 | 300+ | Low test-to-source ratio (12%) |
| Ash Resources | 50 | - | Need consolidation review |
| @spec Annotations | 1,544 | 3,000+ | ~50% coverage estimated |
| @impl true Usage | 2 | 200+ | **Critical gap** - callbacks not annotated |
| @moduledoc false | 29 | <10 | Many modules lack documentation |
| GenServers | 93 | - | Need supervision tree audit |
| Raw SQL Queries | 56 | <20 | Migrate to Ash where possible |
| Dialyzer Errors | 340 | 0 | 304 currently suppressed |
| Files > 500 lines | 175 | <50 | 20% of codebase needs splitting |
| Bounded Contexts | 17 | 10-12 | Potential consolidation needed |
| Feature Flags | 7+ | 2-3 | Query migration flags need cleanup |
| @deprecated Code | 5 | 0 | Remove after updating callers |
| Disabled/Unused Files | 2 | 0 | Delete or restore |
| Legacy Adapters | 2 | 0 | Evaluate and remove |
| Fallback Patterns | 100+ | <30 | Audit for obsolete patterns |

---

## Phase 1: Idiomatic Elixir Patterns Audit

### 1.1 Callback Implementation Annotations (@impl true)

**Priority: CRITICAL**

The codebase has only **2 instances** of `@impl true` despite having **93 GenServers** and numerous behaviour implementations.

**Why This Matters:**
- Compiler can't warn about misspelled callbacks
- No documentation that a function is a callback vs regular function
- Makes refactoring dangerous when behaviours change

**Review Actions:**

```bash
# Find all GenServer modules missing @impl
grep -rln "use GenServer" lib/ | xargs -I{} sh -c \
  'if ! grep -q "@impl true" "{}"; then echo "MISSING @impl: {}"; fi'

# Find all modules with behaviours but no @impl
grep -rln "@behaviour\|use Broadway\|use Phoenix.LiveView" lib/ | \
  xargs -I{} sh -c 'if ! grep -q "@impl true" "{}"; then echo "MISSING @impl: {}"; fi'
```

**Expected Fixes:**
- Add `@impl true` before every `handle_call/3`, `handle_cast/2`, `handle_info/2`, `init/1`
- Add `@impl true` before LiveView callbacks: `mount/3`, `render/1`, `handle_event/3`, `handle_info/2`
- Add `@impl true` before Broadway callbacks: `handle_message/3`, `handle_batch/4`

**Files Requiring Immediate Attention (93 GenServers):**
- All files in `lib/eve_dmv/platform/workers/`
- All files in `lib/eve_dmv/platform/monitoring/`
- All files in `lib/eve_dmv/contexts/*/domain/` with GenServer usage

---

### 1.2 Type Specifications (@spec) Coverage

**Priority: HIGH**

Current coverage: ~1,544 specs across 217 files. Target: All public functions.

**Review Actions:**

```bash
# Find public functions without @spec (sampling)
grep -rB1 "def \w\+(" lib/ --include="*.ex" | \
  grep -v "@spec\|defp\|defmodule\|defmacro" | head -50

# Focus on API modules (should be 100% spec'd)
for api in lib/eve_dmv/contexts/*/api.ex; do
  echo "=== $api ==="
  grep -c "@spec" "$api" || echo "0"
  grep -c "def " "$api" | grep -v defp || echo "0"
done
```

**Checklist:**
- [ ] All context API modules have 100% @spec coverage
- [ ] All public functions in `lib/eve_dmv/platform/` have @specs
- [ ] All Ash resource action callbacks have @specs
- [ ] Complex return types use proper union types `{:ok, t()} | {:error, term()}`

---

### 1.3 Pattern Matching Best Practices

**Priority: MEDIUM**

**Anti-Patterns to Find and Fix:**

```elixir
# ANTI-PATTERN 1: Map access with brackets when pattern matching is better
map[:key]  # Can return nil silently

# BETTER: Use pattern matching or Map.fetch!/2
%{key: value} = map
{:ok, value} = Map.fetch(map, :key)

# ANTI-PATTERN 2: Nil checks instead of pattern matching
if value != nil do ... end

# BETTER: Pattern match
case value do
  nil -> handle_nil()
  value -> handle_value(value)
end

# ANTI-PATTERN 3: Nested case statements
case outer do
  :a -> case inner do ... end
  :b -> ...
end

# BETTER: Use with expressions or extract functions
with {:outer, :a} <- {:outer, outer},
     {:inner, result} <- {:inner, inner} do
  result
end
```

**Review Commands:**

```bash
# Find nil checks that could be pattern matches
grep -rn "!= nil\|== nil" lib/ --include="*.ex"

# Find deeply nested case statements
grep -rn "case.*do" lib/ --include="*.ex" -A 10 | grep -E "^\s+case"

# Find excessive Map.get with defaults
grep -rn "Map.get.*,.*," lib/ --include="*.ex" | wc -l
```

---

### 1.4 Pipe Operator Usage

**Priority: MEDIUM**

**Anti-Patterns:**

```elixir
# ANTI-PATTERN 1: Single-expression pipes
value |> function()  # Unnecessary pipe

# BETTER:
function(value)

# ANTI-PATTERN 2: Pipes broken by variable assignment
result = value
  |> step1()
  |> step2()
intermediate = result |> step3()  # Break in chain

# BETTER: Keep chain together or use with
result =
  value
  |> step1()
  |> step2()
  |> step3()

# ANTI-PATTERN 3: Anonymous function in pipe
list |> Enum.map(fn x -> x * 2 end)

# BETTER (when simple):
list |> Enum.map(&(&1 * 2))
```

---

### 1.5 Error Handling Consistency

**Priority: HIGH**

**Standard Pattern:**
```elixir
# Use {:ok, result} | {:error, reason} consistently
@spec my_function(arg :: term()) :: {:ok, result()} | {:error, error_reason()}

# Use `with` for happy path composition
def complex_operation(input) do
  with {:ok, step1_result} <- step1(input),
       {:ok, step2_result} <- step2(step1_result),
       {:ok, step3_result} <- step3(step2_result) do
    {:ok, step3_result}
  else
    {:error, :step1_failed} -> {:error, :initialization_failed}
    {:error, reason} -> {:error, reason}
  end
end
```

**Review Focus:**
- [ ] Consistent error tuple formats across all contexts
- [ ] No mixing of `{:error, string}` and `{:error, atom}` styles
- [ ] Proper error propagation (not swallowing errors)
- [ ] Meaningful error atoms, not generic `:error`

---

## Phase 2: Ash Framework Optimization

### 2.1 Resource Definition Audit

**Priority: CRITICAL**

Currently: 50 Ash resources across 9 domains.

**Review Checklist per Resource:**

- [ ] **Domain Registration**: Resource registered in appropriate domain
- [ ] **Actions**: All necessary CRUD + custom actions defined
- [ ] **Attributes**: Proper types with constraints
- [ ] **Relationships**: Defined with proper cardinality
- [ ] **Validations**: Business rules in resource, not scattered
- [ ] **Calculations**: Computed values defined as calculations
- [ ] **Aggregates**: Counts, sums defined as aggregates
- [ ] **Authorization**: Policies defined if needed
- [ ] **Identities**: Unique constraints defined

**Sample Resource Audit Template:**

```elixir
# Review each resource for these sections:
defmodule EveDmv.SomeResource do
  use Ash.Resource,
    domain: EveDmv.Api,           # ✓ Domain specified
    data_layer: AshPostgres.DataLayer

  postgres do
    table "table_name"
    repo EveDmv.Repo
  end

  # ✓ Identities for unique constraints
  identities do
    identity :unique_field, [:field]
  end

  # ✓ Actions (not just defaults)
  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:field1, :field2]
      change fn changeset, _ -> ... end
    end

    update :update do
      accept [:field1]
    end

    read :by_id do
      get_by [:id]
    end
  end

  # ✓ Attributes with proper types
  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :status, :atom, constraints: [one_of: [:active, :inactive]]
    timestamps()
  end

  # ✓ Relationships
  relationships do
    belongs_to :parent, EveDmv.Parent
    has_many :children, EveDmv.Child
  end

  # ✓ Validations
  validations do
    validate present(:name)
    validate string_length(:name, min: 1, max: 255)
  end

  # ✓ Calculations for computed values
  calculations do
    calculate :full_name, :string, expr(first_name <> " " <> last_name)
  end

  # ✓ Aggregates
  aggregates do
    count :child_count, :children
    sum :total_value, :children, :value
  end
end
```

---

### 2.2 Raw SQL Migration to Ash

**Priority: HIGH**

Currently: **56 raw SQL queries** using `Ecto.Adapters.SQL.query/3`.

**Categorize Each Query:**

1. **Migrate to Ash Read Actions** - Simple SELECTs
2. **Migrate to Ash Calculations** - Computed values
3. **Migrate to Ash Aggregates** - COUNT, SUM, AVG
4. **Keep as Raw SQL** - Complex CTEs, window functions, PostgreSQL-specific

**Review Process:**

```bash
# List all raw SQL usage
grep -rn "Ecto.Adapters.SQL.query" lib/ --include="*.ex"

# Categorize by file
grep -rln "Ecto.Adapters.SQL.query" lib/ --include="*.ex" | while read f; do
  echo "=== $f ==="
  grep "Ecto.Adapters.SQL.query" "$f" | head -3
done
```

**Migration Examples:**

```elixir
# BEFORE: Raw SQL
def get_character_kill_count(character_id) do
  {:ok, %{rows: [[count]]}} = Ecto.Adapters.SQL.query(
    Repo,
    "SELECT COUNT(*) FROM killmails WHERE character_id = $1",
    [character_id]
  )
  count
end

# AFTER: Ash Aggregate
# In resource:
aggregates do
  count :kill_count, :killmails
end

# Usage:
Ash.load!(character, :kill_count)
```

---

### 2.3 Ash Actions vs Service Functions

**Priority: HIGH**

Many context API modules contain business logic that should be Ash actions.

**Audit Large API Modules:**

| API Module | Lines | Assessment |
|------------|-------|------------|
| killmail_processing/api.ex | 549 | Move batch operations to resource actions |
| corporation_intelligence/api.ex | 471 | Extract analysis to calculations |
| combat_intelligence/api.ex | 422 | Consider read actions with preparations |
| fleet_operations/api.ex | 422 | Move doctrine logic to resource |
| system_analysis/api.ex | 420 | Aggregate queries as Ash aggregates |

**Migration Pattern:**

```elixir
# BEFORE: Logic in API module
defmodule EveDmv.Contexts.SomeContext.Api do
  def get_stats(id) do
    record = Repo.get(Resource, id)
    kills = count_kills(record)
    deaths = count_deaths(record)
    %{kills: kills, deaths: deaths, ratio: kills / max(deaths, 1)}
  end
end

# AFTER: Ash calculations and aggregates
defmodule EveDmv.Contexts.SomeContext.Resources.Character do
  aggregates do
    count :kill_count, :kills
    count :death_count, :deaths
  end

  calculations do
    calculate :kd_ratio, :float, expr(
      kill_count / fragment("GREATEST(?, 1)", death_count)
    )
  end
end

# Usage
Ash.get!(Character, id, load: [:kill_count, :death_count, :kd_ratio])
```

---

### 2.4 Ash Preparations and Filters

**Priority: MEDIUM**

Use Ash preparations for common query patterns.

**Review for Preparation Opportunities:**

```elixir
# BEFORE: Repeated filtering in multiple places
def list_active_users do
  User
  |> Ash.Query.filter(status == :active)
  |> Ash.Query.filter(deleted_at == nil)
  |> Ash.read!()
end

# AFTER: Define as preparation
defmodule EveDmv.Resources.User do
  actions do
    read :list_active do
      prepare fn query, _ ->
        query
        |> Ash.Query.filter(status == :active)
        |> Ash.Query.filter(deleted_at == nil)
      end
    end
  end
end
```

---

### 2.5 Domain Consolidation

**Priority: MEDIUM**

Currently 9 Ash domains - review for consolidation:

| Domain | Purpose | Consolidation Candidate? |
|--------|---------|-------------------------|
| EveDmv.Api | Central domain | Keep as-is |
| EveDmv.Api.AnalyticsApi | Analytics | Merge into Api |
| EveDmv.Api.BattleAnalysisApi | Battle analysis | Merge into Api |
| EveDmv.Api.SurveillanceApi | Surveillance | Keep separate |
| EveDmv.Contexts.BattleAnalysis.Api | Context-specific | Merge into main Api |
| EveDmv.Contexts.FleetOperations.Domain | Fleet ops | Keep context-local |
| EveDmv.Domains.Analytics | Analytics | Duplicate - merge |
| EveDmv.Domains.Intelligence | Intelligence | Keep separate |
| EveDmv.Domains.Surveillance | Surveillance | Duplicate - merge |

**Recommended Structure:**
- `EveDmv.Api` - Core domain with most resources
- `EveDmv.Domains.Intelligence` - Intelligence-specific resources
- `EveDmv.Domains.Surveillance` - Surveillance-specific resources
- Remove duplicate domains

---

## Phase 3: Context Architecture Review

### 3.1 Context Overlap Analysis

**Priority: HIGH**

17 bounded contexts with potential overlap:

**Combat-Related Contexts (5 - Consolidate to 2-3):**
```
├── combat/                    # Core combat resources
├── combat_analysis/           # Combat analysis services
├── combat_intelligence/       # Combat intelligence (45 files!)
├── battle_analysis/           # Battle detection (48 files!)
└── threat_assessment/         # Threat scoring
```

**Recommendation:**
- Merge `combat` + `combat_analysis` → `Combat`
- Merge `combat_intelligence` + `battle_analysis` → `BattleIntelligence`
- Keep `threat_assessment` as separate concern

**Corporation-Related Contexts (3 - Consolidate to 2):**
```
├── corporation/               # Core corporation resources
├── corporation_analysis/      # Corporation analysis
└── corporation_intelligence/  # Corporation intelligence
```

**Recommendation:**
- Keep `corporation/` for resources
- Merge `corporation_analysis` + `corporation_intelligence` → `CorporationIntelligence`

**Intelligence-Related Contexts (4 - Consolidate to 2):**
```
├── intelligence/              # Core intelligence
├── intelligence_infrastructure/  # Regional analysis
├── character_intelligence/    # Character-specific
└── threat_surveillance/       # Threat monitoring
```

**Recommendation:**
- Merge `intelligence` + `intelligence_infrastructure` → `Intelligence`
- Keep `character_intelligence` (distinct domain)
- Keep `threat_surveillance` (distinct concern)

---

### 3.2 Large File Decomposition

**Priority: HIGH**

Files exceeding 1,000 lines need splitting:

| File | Lines | Recommended Split |
|------|-------|-------------------|
| `combat_doctrine_analyzer.ex` | 2,644 | Ship analysis, doctrine analysis, pattern matching |
| `ship_performance_analyzer.ex` | 2,089 | Stats calculator, comparator, visualizer |
| `outcome_analyzer.ex` | 2,030 | Victory conditions, participant analysis, timeline |
| `character_intelligence_analyzer.ex` | 1,894 | Profile builder, threat scorer, pattern detector |
| `threat_scoring_engine.ex` | 1,791 | Score calculator, weight manager, normalizer |
| `battle_analyzer.ex` | 1,698 | Detector, classifier, timeline builder |
| `surveillance_profiles_live.ex` | 1,393 | Extract components, event handlers |
| `fleet_operations_live.ex` | 1,289 | Extract components, async operations |

**Decomposition Pattern:**

```elixir
# BEFORE: Monolithic module
defmodule EveDmv.BigAnalyzer do
  # 2000+ lines of mixed concerns
  def analyze(data), do: ...
  def calculate_score(data), do: ...
  def format_output(data), do: ...
  # ... many more
end

# AFTER: Focused modules
defmodule EveDmv.Analysis.BigAnalyzer do
  alias EveDmv.Analysis.BigAnalyzer.{Calculator, Formatter}

  def analyze(data) do
    data
    |> Calculator.calculate_score()
    |> Formatter.format_output()
  end
end

defmodule EveDmv.Analysis.BigAnalyzer.Calculator do
  @moduledoc "Score calculation logic for BigAnalyzer"
  def calculate_score(data), do: ...
end

defmodule EveDmv.Analysis.BigAnalyzer.Formatter do
  @moduledoc "Output formatting for BigAnalyzer"
  def format_output(data), do: ...
end
```

---

### 3.3 API Module Audit

**Priority: MEDIUM**

API modules should be thin facades, not contain logic.

**Review Criteria:**
- [ ] API module only delegates to domain services
- [ ] No business logic in API module
- [ ] All functions have @doc and @spec
- [ ] Consistent function naming across contexts

**Target Structure:**

```elixir
defmodule EveDmv.Contexts.SomeContext.Api do
  @moduledoc """
  Public API for SomeContext.

  This module serves as the entry point for all SomeContext operations.
  All functions delegate to appropriate domain services.
  """

  alias EveDmv.Contexts.SomeContext.Domain.{ServiceA, ServiceB}

  # Delegations only - no logic here
  defdelegate get_thing(id), to: ServiceA
  defdelegate analyze_thing(thing), to: ServiceB

  # If wrapping is needed, keep it minimal
  @doc "Gets thing with enrichment"
  @spec get_enriched_thing(id :: String.t()) :: {:ok, Thing.t()} | {:error, term()}
  def get_enriched_thing(id) do
    with {:ok, thing} <- ServiceA.get_thing(id),
         {:ok, enriched} <- ServiceB.enrich(thing) do
      {:ok, enriched}
    end
  end
end
```

---

## Phase 4: Type Safety and Dialyzer

### 4.1 Dialyzer Error Resolution

**Priority: CRITICAL**

Current state: **340 errors**, 304 suppressed via `.dialyzer_ignore.exs`.

**Action Plan:**

1. **Categorize Suppressed Errors:**
   ```bash
   cat .dialyzer_ignore.exs
   ```

2. **Fix by Category:**
   - `contract_supertype` - Fix return type specs
   - `pattern_match_cov` - Remove impossible pattern branches
   - `call_to_missing` - Add missing function clauses
   - `guard_fail` - Fix guard conditions

3. **Remove Suppressions as Fixed:**
   - Fix 10 errors per sprint
   - Remove corresponding suppression
   - Verify CI passes

**Common Fix Patterns:**

```elixir
# contract_supertype: Spec too narrow
# BEFORE:
@spec get(id) :: Thing.t()  # But can return nil
def get(id), do: Repo.get(Thing, id)

# AFTER:
@spec get(id) :: Thing.t() | nil
def get(id), do: Repo.get(Thing, id)

# pattern_match_cov: Impossible pattern
# BEFORE:
case status do
  :active -> ...
  :inactive -> ...
  :deleted -> ...  # Never happens - status is only :active | :inactive
end

# AFTER:
case status do
  :active -> ...
  :inactive -> ...
  # Removed impossible case
end
```

---

### 4.2 Type Specification Improvements

**Priority: HIGH**

**Define Custom Types:**

```elixir
# In lib/eve_dmv/types.ex
defmodule EveDmv.Types do
  @moduledoc "Common type definitions for EVE DMV"

  @type character_id :: pos_integer()
  @type corporation_id :: pos_integer()
  @type killmail_id :: pos_integer()
  @type system_id :: pos_integer()

  @type isk_amount :: non_neg_integer()
  @type security_status :: float()

  @type error_reason :: atom() | String.t() | {atom(), term()}
  @type result(t) :: {:ok, t} | {:error, error_reason()}
end
```

**Use in Specs:**

```elixir
@spec get_character(EveDmv.Types.character_id()) ::
  EveDmv.Types.result(Character.t())
```

---

## Phase 5: Test Infrastructure

### 5.1 Coverage Gaps

**Priority: HIGH**

Current: 106 test files for 864 source files (12% ratio).

**High-Priority Test Targets:**

| Area | Source Files | Test Files | Gap |
|------|-------------|------------|-----|
| contexts/combat_intelligence/ | 45 | 3 | Critical |
| contexts/battle_analysis/ | 48 | 5 | Critical |
| contexts/character_intelligence/ | 28 | 4 | High |
| contexts/surveillance/ | 27 | 3 | High |
| platform/database/ | 30 | 2 | High |
| external/eve/ | 20 | 3 | Medium |

**Test Template for Context APIs:**

```elixir
defmodule EveDmv.Contexts.SomeContext.ApiTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.SomeContext.Api

  describe "get_thing/1" do
    test "returns thing when exists" do
      thing = insert(:thing)
      assert {:ok, result} = Api.get_thing(thing.id)
      assert result.id == thing.id
    end

    test "returns error when not found" do
      assert {:error, :not_found} = Api.get_thing(Ecto.UUID.generate())
    end
  end

  describe "analyze_thing/1" do
    test "returns analysis for valid thing" do
      thing = insert(:thing, status: :active)
      assert {:ok, analysis} = Api.analyze_thing(thing)
      assert analysis.score > 0
    end

    test "handles invalid thing gracefully" do
      assert {:error, _reason} = Api.analyze_thing(%{invalid: true})
    end
  end
end
```

---

### 5.2 Ash Resource Testing

**Priority: HIGH**

Test Ash resources properly:

```elixir
defmodule EveDmv.Resources.ThingTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Resources.Thing

  describe "create action" do
    test "creates with valid attributes" do
      assert {:ok, thing} =
        Thing
        |> Ash.Changeset.for_create(:create, %{name: "Test"})
        |> Ash.create()

      assert thing.name == "Test"
    end

    test "validates required fields" do
      assert {:error, changeset} =
        Thing
        |> Ash.Changeset.for_create(:create, %{})
        |> Ash.create()

      assert "is required" in errors_on(changeset).name
    end
  end

  describe "calculations" do
    test "computes derived values" do
      thing = insert(:thing, kills: 10, deaths: 2)
      loaded = Ash.load!(thing, :kd_ratio)
      assert loaded.kd_ratio == 5.0
    end
  end

  describe "aggregates" do
    test "counts related records" do
      parent = insert(:parent)
      insert_list(3, :child, parent: parent)

      loaded = Ash.load!(parent, :child_count)
      assert loaded.child_count == 3
    end
  end
end
```

---

## Phase 6: Documentation Audit

### 6.1 Module Documentation

**Priority: MEDIUM**

29 modules have `@moduledoc false`. Review each:

```bash
grep -rln "@moduledoc false" lib/ --include="*.ex"
```

**Decision Matrix:**

| Module Type | Should Have @moduledoc? |
|-------------|------------------------|
| Public API modules | YES - comprehensive |
| Domain services | YES - purpose description |
| Internal helpers | NO - @moduledoc false OK |
| Generated code | NO - @moduledoc false OK |
| Test support | NO - @moduledoc false OK |

---

### 6.2 Function Documentation

**Priority: MEDIUM**

All public functions should have @doc:

```elixir
@doc """
Retrieves character statistics for the given character ID.

## Parameters

  * `character_id` - The EVE Online character ID

## Returns

  * `{:ok, stats}` - Character statistics map
  * `{:error, :not_found}` - Character not found
  * `{:error, reason}` - Other error

## Examples

    iex> get_character_stats(12345)
    {:ok, %{kills: 100, deaths: 10, isk_destroyed: 1_000_000_000}}

"""
@spec get_character_stats(character_id :: pos_integer()) ::
  {:ok, map()} | {:error, atom()}
def get_character_stats(character_id) do
  # ...
end
```

---

## Phase 7: Performance and Architecture

### 7.1 GenServer Supervision Audit

**Priority: MEDIUM**

93 GenServers need supervision tree review:

- [ ] All GenServers in appropriate supervision tree
- [ ] Restart strategies appropriate for each
- [ ] No orphaned GenServers
- [ ] Graceful shutdown implemented

**Review Application Supervisor:**

```elixir
# Check lib/eve_dmv/application.ex
# Ensure all GenServers are supervised
```

---

### 7.2 N+1 Query Detection

**Priority: HIGH**

Use Ash's built-in loading to prevent N+1:

```elixir
# ANTI-PATTERN: N+1 queries
things = Ash.read!(Thing)
Enum.map(things, fn thing ->
  related = Ash.load!(thing, :related)  # Query per thing!
  # ...
end)

# CORRECT: Bulk load
things = Ash.read!(Thing, load: [:related])
```

---

### 7.3 Caching Strategy Review

**Priority: MEDIUM**

Review Cachex usage for:
- [ ] Appropriate TTLs
- [ ] Cache invalidation on updates
- [ ] No stale data serving
- [ ] Memory bounds configured

---

## Phase 8: Feature Flags and Transitory Code Cleanup

### 8.1 Query Migration Feature Flags

**Priority: HIGH**

The codebase contains a query migration system (`lib/eve_dmv/config/query_migration.ex`) with feature flags for gradual SQL-to-Ash migration.

**Current State:**

| Feature Flag | Status | Action Required |
|--------------|--------|-----------------|
| `use_ash_character_stats` | **COMPLETE** | Remove old SQL code |
| `use_ash_corporation_stats` | **COMPLETE** | Remove old SQL code |
| `use_ash_killmail_queries` | Pending (default: false) | Validate and enable |
| `use_ash_participant_queries` | Pending (default: false) | Validate and enable |
| `log_comparison_mismatches` | Testing tool | Remove after migration |
| `shadow_mode` | Testing tool | Remove after migration |
| `comparison_sample_rate` | Testing tool | Remove after migration |

**Environment Variables to Clean Up:**

```bash
# These can be removed once migrations are complete:
EVE_DMV_QUERY_MIGRATION_USE_ASH_CHARACTER_STATS     # Migration complete
EVE_DMV_QUERY_MIGRATION_USE_ASH_CORPORATION_STATS   # Migration complete
EVE_DMV_QUERY_MIGRATION_USE_ASH_KILLMAIL_QUERIES    # Pending
EVE_DMV_QUERY_MIGRATION_USE_ASH_PARTICIPANT_QUERIES # Pending
EVE_DMV_QUERY_MIGRATION_LOG_COMPARISON_MISMATCHES   # Testing only
EVE_DMV_QUERY_MIGRATION_SHADOW_MODE                 # Testing only
EVE_DMV_QUERY_MIGRATION_COMPARISON_SAMPLE_RATE      # Testing only
```

**Action Plan:**

1. **Complete Pending Migrations:**
   - Enable `use_ash_killmail_queries` in staging
   - Run comparison logging for 1 week
   - Validate results match, then enable in production
   - Repeat for `use_ash_participant_queries`

2. **Remove Migration Infrastructure:**
   - Once all migrations complete, remove `lib/eve_dmv/config/query_migration.ex`
   - Remove old SQL implementations
   - Remove comparison logging code
   - Update CLAUDE.md to remove feature flag documentation

---

### 8.2 Deprecated Code Removal

**Priority: HIGH**

**Modules with @deprecated annotations:**

| File | Deprecated Function/Module | Replacement |
|------|---------------------------|-------------|
| `lib/eve_dmv/contexts/combat/core/battle_analyzer.ex` | `analyze_battle/1` | `OptimizedBattleAnalyzer.analyze_battle/1` |
| `lib/eve_dmv/platform/database/incremental_view_refresher.ex` | Entire module (4 functions) | `MaterializedViewRefresher` |

**Review Commands:**

```bash
# Find all @deprecated annotations
grep -rn "@deprecated" lib/ --include="*.ex"

# Check if deprecated functions are still called
grep -rn "IncrementalViewRefresher\." lib/ --include="*.ex"
grep -rn "battle_analyzer.*analyze_battle" lib/ --include="*.ex"
```

**Action Plan:**

1. Search for callers of deprecated functions
2. Update callers to use new implementations
3. Remove deprecated modules/functions
4. Update any documentation referencing deprecated code

---

### 8.3 Disabled and Unused Files

**Priority: MEDIUM**

**Files to Review and Remove:**

| File | Status | Action |
|------|--------|--------|
| `lib/eve_dmv_web/live/helpers/api_helper.ex.disabled` | Disabled | Delete or restore |
| `lib/eve_dmv/contexts/intelligence/services/analytics_service.ex.unused` | Unused | Delete |

**Review Commands:**

```bash
# Find all disabled/unused files
find lib/ -name "*.disabled" -o -name "*.unused" -o -name "*.bak"

# Check if disabled code is referenced anywhere
grep -rn "ApiHelper" lib/ --include="*.ex"
grep -rn "AnalyticsService" lib/ --include="*.ex"
```

**Decision Matrix:**

- If referenced: Restore and fix
- If not referenced: Delete permanently
- If uncertain: Add TODO with deadline to decide

---

### 8.4 Legacy Adapter Cleanup

**Priority: MEDIUM**

**Legacy/Migration Adapters Found:**

| File | Purpose | Action Required |
|------|---------|-----------------|
| `lib/eve_dmv/intelligence_migration_adapter.ex` | Intelligence system migration | Evaluate if migration complete |
| `lib/eve_dmv/core/infrastructure/legacy_adapter.ex` | Legacy infrastructure bridge | Evaluate if still needed |

**Review Process:**

```bash
# Check if legacy adapters are still used
grep -rn "IntelligenceMigrationAdapter" lib/ --include="*.ex"
grep -rn "LegacyAdapter" lib/ --include="*.ex"
```

**If Still Used:**
- Document why legacy adapter is needed
- Create plan to remove dependency
- Add TODO with target removal date

**If Not Used:**
- Delete the file
- Remove any related configuration

---

### 8.5 Fallback Code Audit

**Priority: LOW**

The codebase contains **100+ fallback patterns** - many may be unnecessary.

**Categories of Fallbacks:**

1. **Legitimate Fallbacks** (Keep):
   - API unavailable → use cached data
   - External service timeout → use estimates
   - Data migration period → support both formats

2. **Legacy Format Support** (Review):
   - "Legacy format support" comments
   - "Old participants format" handling
   - "Legacy timestamp format" parsing

3. **Defensive Fallbacks** (Potentially Remove):
   - Fallbacks for cases that can no longer happen
   - Fallbacks for removed features
   - Overly defensive nil handling

**Review Commands:**

```bash
# Find all fallback comments
grep -rn "# [Ff]allback\|# [Ll]egacy" lib/ --include="*.ex"

# Count by file to find hotspots
grep -rln "# [Ff]allback\|# [Ll]egacy" lib/ --include="*.ex" | \
  xargs -I{} sh -c 'echo "$(grep -c "# [Ff]allback\|# [Ll]egacy" {}) {}"' | \
  sort -rn | head -20
```

**Fallback Hotspots (Files with Most Fallbacks):**

| File | Fallback Count | Review Priority |
|------|---------------|-----------------|
| `ship_performance_analyzer.ex` | 8+ | High - may have obsolete fallbacks |
| `valuation_service.ex` | 6+ | Medium - API fallbacks likely valid |
| `member_activity_analyzer.ex` | 5+ | Medium - ESI fallbacks likely valid |
| `external_price_client.ex` | 4+ | Medium - API fallbacks likely valid |
| `display_service.ex` | 3+ | High - "old format" may be removable |

**Review Checklist for Each Fallback:**

- [ ] Is the primary code path still valid?
- [ ] Can the fallback condition actually occur?
- [ ] When was this fallback added? Is it still relevant?
- [ ] Is this supporting a migration that's complete?
- [ ] Should this be a proper error instead of silent fallback?

---

### 8.6 Configuration Flag Cleanup

**Priority: MEDIUM**

**Other Configuration Flags to Review:**

```elixir
# In config/runtime.exs and runtime_logger.exs
DISABLE_STRUCTURED_LOGGING  # Why would this be disabled?

# Pipeline control
PIPELINE_ENABLED            # Should this always be true in prod?
MOCK_SSE_SERVER_ENABLED     # Dev/test only - verify not in prod config

# Historical fetch (review if needed)
HISTORICAL_FETCH_ENABLED    # Should this be permanent?
```

**Action Items:**

1. **Audit All Feature Flags:**
   ```bash
   grep -rn "System.get_env\|Application.get_env" config/ lib/eve_dmv/config/
   ```

2. **Categorize Each Flag:**
   - **Permanent**: Keep and document
   - **Environment-specific**: Ensure proper defaults
   - **Transitory**: Plan for removal

3. **Update Documentation:**
   - Remove references to completed migrations
   - Document permanent flags in CLAUDE.md
   - Remove temporary flag documentation

---

### 8.7 Dead Code Detection

**Priority: MEDIUM**

**Tools and Commands:**

```bash
# Find potentially unused modules
mix xref graph --format stats

# Find unreachable code
mix xref unreachable

# Find unused functions (requires dialyzer with unused_fun)
# Note: Currently disabled in dialyzer config

# Find modules with no callers
mix xref graph --sink ModuleName
```

**Common Dead Code Patterns:**

1. **Orphaned Modules:**
   - Modules created but never integrated
   - Modules from abandoned features
   - Test helpers in main lib/

2. **Unused Private Functions:**
   - Functions created for future use
   - Functions obsoleted by refactoring
   - Helper functions whose callers were removed

3. **Unused Configuration:**
   - Config keys that are never read
   - Environment variables not used

**Review Process:**

1. Run `mix xref unreachable` weekly
2. Investigate any reported modules
3. Either integrate or delete orphaned code
4. Document intentionally unused code (e.g., public API)

---

### 8.8 Transitory Code Summary

**Complete Inventory:**

| Category | Count | Priority | Sprint Target |
|----------|-------|----------|---------------|
| Query Migration Flags | 7 | HIGH | Sprint 2 |
| @deprecated Functions | 5 | HIGH | Sprint 1 |
| Disabled/Unused Files | 2 | MEDIUM | Sprint 1 |
| Legacy Adapters | 2 | MEDIUM | Sprint 3 |
| Fallback Code Hotspots | 20+ files | LOW | Ongoing |
| Config Flags to Review | 5+ | MEDIUM | Sprint 2 |

**Success Criteria:**

- [ ] All completed migrations have old code removed
- [ ] No `.disabled` or `.unused` files remain
- [ ] All @deprecated code either removed or has removal date
- [ ] Legacy adapters documented or removed
- [ ] Fallback audit complete for high-priority files
- [ ] Query migration infrastructure removed
- [ ] Feature flag count reduced by 50%

---

## Execution Roadmap

### Sprint 1: Critical Fixes (Week 1-2)

1. **@impl true Audit** - Add to all 93 GenServers
2. **Dialyzer Triage** - Categorize 340 errors
3. **Fix Top 50 Dialyzer Errors** - Remove from ignore file
4. **Remove Disabled/Unused Files** - Delete 2 files
5. **Remove @deprecated Code** - After updating callers

### Sprint 2: Ash Optimization (Week 3-4)

1. **Resource Audit** - Review all 50 resources
2. **Raw SQL Migration** - Convert 20 queries to Ash
3. **Action Refactoring** - Move logic from API to resources
4. **Complete Query Migration Flags** - Enable remaining Ash queries
5. **Remove Query Migration Infrastructure** - Delete migration module

### Sprint 3: Context Consolidation (Week 5-6)

1. **Combat Context Merge** - 5 → 3 contexts
2. **Corporation Context Merge** - 3 → 2 contexts
3. **Large File Splits** - Top 10 files
4. **Legacy Adapter Review** - Remove or document

### Sprint 4: Test Coverage (Week 7-8)

1. **Context API Tests** - All 17 contexts
2. **Resource Tests** - All 50 resources
3. **Integration Tests** - Critical paths

### Sprint 5: Polish (Week 9-10)

1. **Documentation** - All public modules
2. **Type Specs** - 100% public function coverage
3. **Remaining Dialyzer** - Zero errors goal
4. **Fallback Code Audit** - Review high-priority files
5. **Final Dead Code Sweep** - Remove any remaining orphans

---

## Quality Gates

### Before Merging Any PR:

- [ ] `mix format --check-formatted` passes
- [ ] `mix credo --strict` passes
- [ ] `mix dialyzer` passes (no new errors)
- [ ] `mix test` passes
- [ ] Coverage doesn't decrease
- [ ] New public functions have @spec and @doc
- [ ] GenServer callbacks have @impl true

### Weekly Review:

- [ ] Dialyzer error count decreasing
- [ ] Test coverage increasing
- [ ] Large files being split
- [ ] Context overlap being reduced

---

## Automated Tooling

### Pre-commit Hook

```bash
#!/bin/bash
mix format --check-formatted || exit 1
mix credo --strict || exit 1
mix compile --warnings-as-errors || exit 1
```

### CI Pipeline Additions

```yaml
- name: Check @impl annotations
  run: |
    count=$(grep -r "@impl true" lib/ | wc -l)
    if [ $count -lt 100 ]; then
      echo "Only $count @impl annotations found, expected 100+"
      exit 1
    fi

- name: Check spec coverage
  run: |
    public=$(grep -r "def \w\+(" lib/ | grep -v defp | wc -l)
    specs=$(grep -r "@spec" lib/ | wc -l)
    ratio=$((specs * 100 / public))
    if [ $ratio -lt 80 ]; then
      echo "Spec coverage is $ratio%, expected 80%+"
      exit 1
    fi
```

---

## Appendix A: File Size Inventory

### Files > 1,500 Lines (Immediate Split Required)

1. `combat_doctrine_analyzer.ex` - 2,644 lines
2. `ship_performance_analyzer.ex` - 2,089 lines
3. `outcome_analyzer.ex` - 2,030 lines
4. `character_intelligence_analyzer.ex` - 1,894 lines
5. `threat_scoring_engine.ex` - 1,791 lines
6. `battle_analyzer.ex` - 1,698 lines
7. `tactical_patterns.ex` - 1,560 lines

### Files 1,000-1,500 Lines (Split Recommended)

8. `composition_analyzer.ex` - 1,469 lines
9. `surveillance_profiles_live.ex` - 1,393 lines
10. `timeline_analyzer.ex` - 1,332 lines
11. `fleet_operations_live.ex` - 1,289 lines
12. `recruitment_service.ex` - 1,289 lines
13. `advanced_fleet_analyzer.ex` - 1,285 lines
14. `battle_analysis_live.ex` - 1,257 lines
15. `recommendation_engine.ex` - 1,254 lines
... (15 more files between 1,000-1,200 lines)

---

## Appendix B: Context File Counts

| Context | Files | Assessment |
|---------|-------|------------|
| battle_analysis | 48 | Large - consider splitting |
| combat_intelligence | 45 | Large - consider merging with battle_analysis |
| fleet_operations | 31 | Appropriate |
| character_intelligence | 28 | Appropriate |
| surveillance | 27 | Appropriate |
| corporation | 23 | Appropriate |
| corporation_intelligence | 23 | Consider merging with corporation_analysis |
| intelligence | 21 | Consider merging with intelligence_infrastructure |
| combat | 20 | Consider merging with combat_analysis |
| intelligence_infrastructure | 16 | Merge candidate |
| killmail_processing | 12 | Appropriate |
| threat_surveillance | 8 | Appropriate |
| corporation_analysis | 8 | Merge candidate |
| combat_analysis | 8 | Merge candidate |
| system_analysis | 6 | Appropriate |
| market_intelligence | 6 | Appropriate |
| player_profile | 6 | Appropriate |
| threat_assessment | 6 | Appropriate |
| battle_sharing | 5 | Appropriate |

---

## Appendix C: Ash Resource Distribution

### By Domain

| Domain | Resource Count |
|--------|---------------|
| EveDmv.Api | 25+ |
| Context-specific | 20+ |
| Surveillance | 5 |

### Resources Needing Review

1. **Duplicate Resources** - Same concept in multiple contexts
2. **Thin Resources** - Could be merged
3. **Missing Resources** - Data accessed via raw SQL

---

## Success Criteria

After completing this review plan:

### Code Quality
1. **Zero Dialyzer Errors** - All 340 resolved or properly justified
2. **@impl true on All Callbacks** - 200+ annotations (up from 2)
3. **80%+ Spec Coverage** - Up from ~50%
4. **No Files > 1,000 Lines** - All large files split
5. **All Public Modules Documented** - @moduledoc on all

### Architecture
6. **Context Count Reduced** - 17 → 10-12 contexts
7. **Raw SQL Reduced** - 56 → <20 queries
8. **Test Coverage > 60%** - Up from ~40%

### Transitory Code Cleanup
9. **Feature Flags Reduced** - 7+ → 2-3 permanent flags only
10. **Zero @deprecated Code** - All deprecated functions removed
11. **No Disabled/Unused Files** - All `.disabled`/`.unused` files resolved
12. **Legacy Adapters Removed** - Migration adapters deleted or documented
13. **Fallback Audit Complete** - 100+ → <30 legitimate fallbacks
14. **Query Migration Complete** - All Ash migrations enabled, infrastructure removed
