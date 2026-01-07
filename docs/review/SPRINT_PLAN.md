# EVE DMV Technical Debt Sprint Plan

**Generated:** 2026-01-06
**Based on:** CODE_REVIEW_SUMMARY.md
**Duration:** 2-week sprint
**Structure:** Parallel work tracks for AI assistant execution

---

## Overview

This sprint plan addresses the critical and high-priority findings from the code review. Tasks are organized into **parallel work tracks** that can be executed simultaneously without conflicts.

### Work Track Summary

| Track | Focus Area                | Tasks   | Can Parallelize With |
| ----- | ------------------------- | ------- | -------------------- |
| A     | Test Coverage             | 6 tasks | B, C, D, E           |
| B     | File Decomposition        | 4 tasks | A, C, D, E           |
| C     | API Refactoring           | 3 tasks | A, B, D, E           |
| D     | Dialyzer Fixes            | 2 tasks | A, B, C, E           |
| E     | Documentation             | 3 tasks | A, B, C, D           |
| F     | Architecture (Sequential) | 3 tasks | After A-E            |

---

## Track A: Test Coverage (Parallel)

These tasks add tests to critical modules. Each task is independent and can run in parallel.

### A.1: Test combat_intelligence/domain/threat_assessor.ex

**Priority:** Critical
**Estimated Effort:** 2-3 hours
**Dependencies:** None
**Can Run With:** A.2, A.3, A.4, A.5, A.6, B._, C._, D._, E._

**Context:**
The `ThreatAssessor` module calculates threat levels for characters and entities based on combat history. It is a core security feature that currently has no tests.

**Source File:**

- Path: `lib/eve_dmv/contexts/combat_intelligence/domain/threat_assessor.ex`
- Lines: ~400
- Key Functions:
  - `assess_threat/2` - Main entry point
  - `calculate_threat_score/1` - Scoring algorithm
  - `analyze_combat_patterns/1` - Pattern analysis

**Test File to Create:**

- Path: `test/eve_dmv/contexts/combat_intelligence/domain/threat_assessor_test.exs`

**Implementation Instructions:**

1. Read the source file to understand:

   - Public function signatures and their @spec annotations
   - Expected input/output formats
   - Edge cases handled in the code

2. Create test file with structure:

```elixir
defmodule EveDmv.Contexts.CombatIntelligence.Domain.ThreatAssessorTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CombatIntelligence.Domain.ThreatAssessor

  describe "assess_threat/2" do
    test "returns threat assessment for valid character_id" do
      # Test with mock data
    end

    test "returns error for invalid character_id" do
      # Test error handling
    end

    test "handles character with no combat history" do
      # Edge case
    end
  end

  describe "calculate_threat_score/1" do
    test "calculates score based on kill/death ratio" do
      # Test scoring logic
    end

    test "weights recent activity higher" do
      # Test time-based weighting
    end
  end
end
```

3. Use fixtures or factories for test data. Check `test/support/` for existing helpers.

4. Run tests: `MIX_ENV=test mix test test/eve_dmv/contexts/combat_intelligence/domain/threat_assessor_test.exs`

**Acceptance Criteria:**

- [ ] Test file created at correct path
- [ ] All public functions have at least one test
- [ ] Edge cases covered (nil input, empty data, invalid IDs)
- [ ] Tests pass: `mix test test/eve_dmv/contexts/combat_intelligence/domain/threat_assessor_test.exs`
- [ ] No new warnings introduced

---

### A.2: Test combat_intelligence/domain/intelligence_scoring.ex

**Priority:** Critical
**Estimated Effort:** 2-3 hours
**Dependencies:** None
**Can Run With:** A.1, A.3, A.4, A.5, A.6, B._, C._, D._, E._

**Context:**
The `IntelligenceScoring` module provides scoring algorithms for combat intelligence analysis. This is a computational module with clear inputs/outputs.

**Source File:**

- Path: `lib/eve_dmv/contexts/combat_intelligence/domain/intelligence_scoring.ex`
- Key Functions: Look for public `def` functions, especially those with `@spec`

**Test File to Create:**

- Path: `test/eve_dmv/contexts/combat_intelligence/domain/intelligence_scoring_test.exs`

**Implementation Instructions:**

1. Read source file to identify:

   - All public functions (functions without `defp`)
   - Input types from @spec annotations
   - Return value patterns

2. Create comprehensive tests for each scoring function:

   - Normal inputs
   - Boundary values (0, negative, very large)
   - Empty collections
   - Nil handling

3. Test mathematical accuracy where applicable.

**Acceptance Criteria:**

- [ ] Test file created
- [ ] 80%+ code coverage for this module
- [ ] Tests pass independently

---

### A.3: Test surveillance/domain/matching_engine.ex

**Priority:** Critical
**Estimated Effort:** 3-4 hours
**Dependencies:** None
**Can Run With:** A.1, A.2, A.4, A.5, A.6, B._, C._, D._, E._

**Context:**
The `MatchingEngine` is a GenServer that matches incoming killmails against user-defined surveillance profiles. This is a critical real-time feature.

**Source File:**

- Path: `lib/eve_dmv/contexts/surveillance/domain/matching_engine.ex`
- Lines: ~1,044
- Type: GenServer
- Key Functions:
  - `start_link/1` - GenServer initialization
  - `match_killmail/1` - Main matching logic
  - `handle_call/handle_cast/handle_info` - Callbacks

**Test File to Create:**

- Path: `test/eve_dmv/contexts/surveillance/domain/matching_engine_test.exs`

**Implementation Instructions:**

1. For GenServer testing, use the pattern:

```elixir
defmodule EveDmv.Contexts.Surveillance.Domain.MatchingEngineTest do
  use EveDmv.DataCase, async: false  # GenServers may need async: false

  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine

  setup do
    # Start a test instance of the GenServer if needed
    # Or use the application-started instance
    :ok
  end

  describe "match_killmail/1" do
    test "matches killmail against active profiles" do
      # Create test profile
      # Create test killmail
      # Assert match result
    end

    test "returns empty list when no profiles match" do
      # Test no-match case
    end
  end
end
```

2. Test the matching logic thoroughly:
   - Character ID matches
   - Corporation ID matches
   - Alliance ID matches
   - System/region matches
   - Ship type matches
   - Combined criteria

**Acceptance Criteria:**

- [ ] Test file created
- [ ] GenServer lifecycle tested
- [ ] Matching logic comprehensively tested
- [ ] Tests pass

---

### A.4: Test surveillance/domain/notification_service.ex

**Priority:** High
**Estimated Effort:** 2 hours
**Dependencies:** None
**Can Run With:** All other tasks

**Source File:**

- Path: `lib/eve_dmv/contexts/surveillance/domain/notification_service.ex`

**Test File to Create:**

- Path: `test/eve_dmv/contexts/surveillance/domain/notification_service_test.exs`

**Implementation Instructions:**

1. Read source to understand notification delivery mechanisms
2. Test notification creation, formatting, and delivery
3. Mock external services if notifications go to external systems

**Acceptance Criteria:**

- [ ] Test file created
- [ ] Core notification functions tested
- [ ] Tests pass

---

### A.5: Test character_intelligence/domain/threat_scoring_engine.ex

**Priority:** High
**Estimated Effort:** 3-4 hours
**Dependencies:** None
**Can Run With:** All other tasks

**Context:**
Large file (1,791 lines) containing threat scoring algorithms. Focus on public API.

**Source File:**

- Path: `lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring_engine.ex`
- Lines: 1,791

**Test File to Create:**

- Path: `test/eve_dmv/contexts/character_intelligence/domain/threat_scoring_engine_test.exs`

**Implementation Instructions:**

1. Identify the main public entry points (likely 5-10 functions)
2. Focus tests on these public functions
3. Use `ThreatConfig` module for expected threshold values

**Acceptance Criteria:**

- [ ] Test file created
- [ ] Main scoring functions tested
- [ ] Tests pass

---

### A.6: Test battle_analysis/core/battle_detector.ex

**Priority:** High
**Estimated Effort:** 2-3 hours
**Dependencies:** None
**Can Run With:** All other tasks

**Source File:**

- Path: `lib/eve_dmv/contexts/battle_analysis/core/battle_detector.ex`

**Test File to Create:**

- Path: `test/eve_dmv/contexts/battle_analysis/core/battle_detector_test.exs`

**Implementation Instructions:**

1. Test battle detection algorithms
2. Test clustering logic for grouping killmails
3. Test time window calculations

**Acceptance Criteria:**

- [ ] Test file created
- [ ] Detection algorithms tested
- [ ] Tests pass

---

## Track B: File Decomposition (Parallel)

These tasks split large files into smaller, focused modules. Each can run independently.

### B.1: Split combat_doctrine_analyzer.ex (2,644 lines)

**Priority:** Critical
**Estimated Effort:** 4-5 hours
**Dependencies:** None
**Can Run With:** A._, B.2, B.3, B.4, C._, D._, E._

**Source File:**

- Path: `lib/eve_dmv/contexts/corporation_intelligence/domain/combat_doctrine_analyzer.ex`
- Lines: 2,644
- Context: Corporation Intelligence

**Analysis Instructions:**

1. Read the file and identify logical groupings:

```bash
# Count functions
grep -c "^\s*def " lib/eve_dmv/contexts/corporation_intelligence/domain/combat_doctrine_analyzer.ex

# List function names
grep "^\s*def " lib/eve_dmv/contexts/corporation_intelligence/domain/combat_doctrine_analyzer.ex
```

2. Likely groupings to extract:
   - **Doctrine Identification** - Functions that identify doctrine from fleet composition
   - **Doctrine Analysis** - Functions that analyze doctrine effectiveness
   - **Doctrine History** - Functions that track doctrine changes over time
   - **Doctrine Recommendations** - Functions that recommend doctrines

**Implementation Instructions:**

1. Create new directory structure:

```
lib/eve_dmv/contexts/corporation_intelligence/domain/doctrine/
├── doctrine_identifier.ex      # Identify doctrines from compositions
├── doctrine_analyzer.ex        # Analyze doctrine effectiveness
├── doctrine_tracker.ex         # Historical doctrine tracking
└── doctrine_recommender.ex     # Doctrine recommendations
```

2. For each new module:

   - Move related functions
   - Update module name
   - Add `@moduledoc` documentation
   - Add `@spec` to public functions
   - Keep private helper functions with their callers

3. Update the original file to:

   - Delegate to new modules OR
   - Remove it entirely and update all callers

4. Find and update all callers:

```bash
grep -rn "CombatDoctrineAnalyzer" lib/ --include="*.ex"
```

5. Run tests and dialyzer:

```bash
mix test
mix dialyzer
```

**Acceptance Criteria:**

- [ ] Original file split into 3-4 focused modules
- [ ] Each new module <500 lines
- [ ] All callers updated
- [ ] Tests pass
- [ ] Dialyzer passes
- [ ] No functionality lost

---

### B.2: Split ship_performance_analyzer.ex (2,128 lines)

**Priority:** Critical
**Estimated Effort:** 4-5 hours
**Dependencies:** None
**Can Run With:** A._, B.1, B.3, B.4, C._, D._, E._

**Source File:**

- Path: `lib/eve_dmv/contexts/battle_analysis/domain/ship_performance_analyzer.ex`
- Lines: 2,128

**Suggested Split:**

```
lib/eve_dmv/contexts/battle_analysis/domain/ship_analysis/
├── ship_performance_calculator.ex   # Raw performance calculations
├── ship_effectiveness_scorer.ex     # Effectiveness scoring
├── ship_role_analyzer.ex            # Role-based analysis
└── ship_comparison_engine.ex        # Ship comparisons
```

**Implementation Instructions:**
Same process as B.1. Focus on grouping by ship analysis responsibility.

**Acceptance Criteria:**

- [ ] File split into focused modules
- [ ] Each module <500 lines
- [ ] Tests pass
- [ ] Dialyzer passes

---

### B.3: Split outcome_analyzer.ex (2,030 lines)

**Priority:** Critical
**Estimated Effort:** 4-5 hours
**Dependencies:** None
**Can Run With:** A._, B.1, B.2, B.4, C._, D._, E._

**Source File:**

- Path: `lib/eve_dmv/contexts/combat_intelligence/domain/phases/outcome_analyzer.ex`
- Lines: 2,030

**Suggested Split:**

```
lib/eve_dmv/contexts/combat_intelligence/domain/phases/outcome/
├── outcome_calculator.ex      # Calculate battle outcomes
├── outcome_predictor.ex       # Predict likely outcomes
├── outcome_reporter.ex        # Generate outcome reports
└── outcome_statistics.ex      # Statistical analysis
```

**Acceptance Criteria:**

- [ ] File split into focused modules
- [ ] Each module <500 lines
- [ ] Tests pass

---

### B.4: Split character_intelligence_analyzer.ex (1,894 lines)

**Priority:** High
**Estimated Effort:** 3-4 hours
**Dependencies:** None
**Can Run With:** A._, B.1, B.2, B.3, C._, D._, E._

**Source File:**

- Path: `lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex`
- Lines: 1,894

**Suggested Split:**

```
lib/eve_dmv/contexts/character_intelligence/analyzers/
├── character_combat_analyzer.ex     # Combat analysis
├── character_activity_analyzer.ex   # Activity patterns
├── character_social_analyzer.ex     # Social connections
└── character_risk_analyzer.ex       # Risk assessment
```

**Acceptance Criteria:**

- [ ] File split
- [ ] Each module <500 lines
- [ ] Tests pass

---

## Track C: API Refactoring (Parallel)

Refactor API modules to delegate business logic to domain services.

### C.1: Refactor killmail_processing/api.ex

**Priority:** Critical
**Estimated Effort:** 3-4 hours
**Dependencies:** None
**Can Run With:** A._, B._, C.2, C.3, D._, E._

**Source File:**

- Path: `lib/eve_dmv/contexts/killmail_processing/api.ex`
- Current Lines: 549
- Target Lines: <200
- Logic Blocks: 34 (target: 0)

**Analysis:**

```bash
# See current structure
wc -l lib/eve_dmv/contexts/killmail_processing/api.ex
grep -c "case \|if \|with " lib/eve_dmv/contexts/killmail_processing/api.ex
```

**Implementation Instructions:**

1. **Identify business logic** - Look for `case`, `if`, `with`, and multi-line function bodies

2. **Create domain services** for extracted logic:

```
lib/eve_dmv/contexts/killmail_processing/domain/
├── ingestion_service.ex      # Killmail ingestion logic
├── enrichment_service.ex     # Data enrichment logic
├── statistics_service.ex     # Statistics calculations
└── validation_service.ex     # Input validation
```

3. **Refactor API to delegations:**

Before:

```elixir
def ingest_killmail(killmail_data) do
  with {:ok, validated} <- validate_killmail(killmail_data),
       {:ok, enriched} <- enrich_killmail(validated),
       {:ok, result} <- save_killmail(enriched) do
    {:ok, result}
  end
end

defp validate_killmail(data) do
  # 20 lines of validation logic
end
```

After:

```elixir
@doc "Ingest a killmail into the processing pipeline."
@spec ingest_killmail(map()) :: {:ok, KillmailRaw.t()} | {:error, term()}
defdelegate ingest_killmail(killmail_data), to: IngestionService
```

4. **Update tests** if any exist for the API module

5. **Verify all callers still work:**

```bash
grep -rn "KillmailProcessing.Api\." lib/ --include="*.ex"
grep -rn "KillmailProcessing.ingest" lib/ --include="*.ex"
```

**Acceptance Criteria:**

- [ ] API module <200 lines
- [ ] 0 logic blocks (case/if/with) in API
- [ ] All functions have @doc and @spec
- [ ] Business logic moved to domain services
- [ ] Tests pass
- [ ] No functionality lost

---

### C.2: Refactor fleet_operations/api.ex

**Priority:** Critical
**Estimated Effort:** 3-4 hours
**Dependencies:** None
**Can Run With:** A._, B._, C.1, C.3, D._, E._

**Source File:**

- Path: `lib/eve_dmv/contexts/fleet_operations/api.ex`
- Current Lines: 405
- Logic Blocks: 28

**Implementation Instructions:**
Same pattern as C.1. Extract to domain services:

- `fleet_composition_service.ex`
- `fleet_analysis_service.ex`
- `doctrine_service.ex`

**Acceptance Criteria:**

- [ ] API module <200 lines
- [ ] 0 logic blocks
- [ ] Tests pass

---

### C.3: Refactor surveillance/api.ex

**Priority:** High
**Estimated Effort:** 2-3 hours
**Dependencies:** None
**Can Run With:** A._, B._, C.1, C.2, D._, E._

**Source File:**

- Path: `lib/eve_dmv/contexts/surveillance/api.ex`
- Current Lines: 405
- Logic Blocks: 20

**Implementation Instructions:**
Extract validation logic to Profile resource validations (Ash pattern).
Extract business logic to domain services.

**Acceptance Criteria:**

- [ ] API module <200 lines
- [ ] Validations moved to Ash resource
- [ ] Tests pass

---

## Track D: Dialyzer Fixes (Parallel)

Fix active dialyzer errors.

### D.1: Fix battle_analysis_utils.ex Guard Failures

**Priority:** High
**Estimated Effort:** 1-2 hours
**Dependencies:** None
**Can Run With:** A._, B._, C._, D.2, E._

**Source File:**

- Path: `lib/eve_dmv/contexts/battle_analysis/shared/battle_analysis_utils.ex`
- Errors: 4 guard_fail errors at lines 40, 71, 101, 128

**Error Description:**

```
Guard clause `when _ :: maybe_improper_list() === nil` can never succeed.
```

**Analysis Instructions:**

1. Read the file and locate the problematic guards:

```bash
sed -n '38,42p' lib/eve_dmv/contexts/battle_analysis/shared/battle_analysis_utils.ex
sed -n '69,73p' lib/eve_dmv/contexts/battle_analysis/shared/battle_analysis_utils.ex
```

2. The error suggests a function has a guard checking if a list equals nil, but the type system knows the parameter is always a list.

**Fix Options:**

Option A - Remove unnecessary guard:

```elixir
# Before
def process(data) when data == nil, do: []
def process(data) when is_list(data), do: ...

# After (if nil is never passed based on callers)
def process(data) when is_list(data), do: ...
```

Option B - Fix @spec to include nil:

```elixir
# Before
@spec process(list()) :: list()

# After
@spec process(list() | nil) :: list()
```

Option C - Add explicit nil clause:

```elixir
def process(nil), do: []
def process(data) when is_list(data), do: ...
```

**Verification:**

```bash
mix dialyzer 2>&1 | grep battle_analysis_utils
```

**Acceptance Criteria:**

- [ ] All 4 guard_fail errors resolved
- [ ] `mix dialyzer` passes for this file
- [ ] Tests still pass

---

### D.2: Fix battle_analysis_live.ex Errors

**Priority:** High
**Estimated Effort:** 1 hour
**Dependencies:** None
**Can Run With:** A._, B._, C._, D.1, E._

**Source File:**

- Path: `lib/eve_dmv_web/live/battle_analysis_live.ex`
- Errors:
  - Line 634: `no_return` - Function `format_error_reason/1` has no local return
  - Line 642: `guard_fail` - Guard `is_binary(reason)` can never succeed

**Analysis:**

```bash
sed -n '630,650p' lib/eve_dmv_web/live/battle_analysis_live.ex
```

**Fix Instructions:**

1. For `no_return`: The function likely has pattern matches that don't cover all cases. Add a catch-all clause:

```elixir
def format_error_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
def format_error_reason({:invalid_rating, :out_of_range}), do: "Rating out of range"
def format_error_reason(reason) when is_binary(reason), do: reason
def format_error_reason(other), do: inspect(other)  # Add catch-all
```

2. For `guard_fail` on `is_binary`: The @spec or type restricts input to atoms/tuples only. Either:
   - Remove the binary clause if strings are never passed
   - Update the type to include String.t()

**Verification:**

```bash
mix dialyzer 2>&1 | grep battle_analysis_live
```

**Acceptance Criteria:**

- [ ] Both errors resolved
- [ ] `mix dialyzer` passes for this file
- [ ] LiveView still functions correctly

---

## Track E: Documentation (Parallel)

Add missing documentation to API modules.

### E.1: Document killmail_processing/api.ex

**Priority:** High
**Estimated Effort:** 2 hours
**Dependencies:** None (can run before or after C.1)
**Can Run With:** A._, B._, C._, D._, E.2, E.3

**Source File:**

- Path: `lib/eve_dmv/contexts/killmail_processing/api.ex`
- Missing @doc: 22 functions

**Implementation Instructions:**

1. List all public functions:

```bash
grep "^\s*def [a-z]" lib/eve_dmv/contexts/killmail_processing/api.ex
```

2. For each function, add @doc above it:

```elixir
@doc """
Ingests a killmail into the processing pipeline.

## Parameters

  - `killmail_data` - Map containing killmail data from ESI or wanderer-kills

## Returns

  - `{:ok, killmail}` - Successfully ingested killmail
  - `{:error, reason}` - Error with reason atom

## Examples

    iex> KillmailProcessing.ingest_killmail(%{killmail_id: 123, ...})
    {:ok, %KillmailRaw{}}
"""
@spec ingest_killmail(map()) :: {:ok, KillmailRaw.t()} | {:error, term()}
def ingest_killmail(killmail_data) do
```

3. Run `mix docs` to verify documentation generates correctly.

**Acceptance Criteria:**

- [ ] All 22 public functions have @doc
- [ ] Documentation follows consistent format
- [ ] `mix docs` generates without warnings

---

### E.2: Document surveillance/api.ex

**Priority:** High
**Estimated Effort:** 1.5 hours
**Dependencies:** None
**Can Run With:** A._, B._, C._, D._, E.1, E.3

**Source File:**

- Path: `lib/eve_dmv/contexts/surveillance/api.ex`
- Missing @doc: 16 functions

**Implementation Instructions:**
Same pattern as E.1.

**Acceptance Criteria:**

- [ ] All 16 functions documented
- [ ] `mix docs` passes

---

### E.3: Document combat_intelligence/api.ex

**Priority:** High
**Estimated Effort:** 1.5 hours
**Dependencies:** None
**Can Run With:** A._, B._, C._, D._, E.1, E.2

**Source File:**

- Path: `lib/eve_dmv/contexts/combat_intelligence/api.ex`
- Missing @doc: 15 functions

**Implementation Instructions:**
Same pattern as E.1.

**Acceptance Criteria:**

- [ ] All 15 functions documented
- [ ] `mix docs` passes

---

## Track F: Architecture (Sequential - After A-E)

These tasks modify shared architecture and should run after other tracks complete.

### F.1: Consolidate Duplicate Battle Resources

**Priority:** High
**Estimated Effort:** 3-4 hours
**Dependencies:** Complete A._, B._, C.\* first
**Can Run With:** F.2, F.3 (with care)

**Context:**
Duplicate Ash resources exist between contexts:

- `lib/eve_dmv/contexts/combat/resources/battle.ex`
- `lib/eve_dmv/contexts/battle_analysis/resources/battle.ex`

**Analysis:**

```bash
diff lib/eve_dmv/contexts/combat/resources/battle.ex \
     lib/eve_dmv/contexts/battle_analysis/resources/battle.ex
```

**Implementation Instructions:**

1. Compare both Battle resources to identify differences
2. Choose canonical location (recommend `battle_analysis`)
3. Update all references to combat version:

```bash
grep -rn "Combat.Resources.Battle\|Combat.Battle" lib/ --include="*.ex"
```

4. Remove duplicate
5. Repeat for: BattleKillmail, CombatLog, ShipFitting

**Acceptance Criteria:**

- [ ] Single Battle resource exists
- [ ] Single BattleKillmail resource exists
- [ ] All references updated
- [ ] Tests pass
- [ ] Dialyzer passes

---

### F.2: Consolidate Battle Analysis Domains

**Priority:** Medium
**Estimated Effort:** 2-3 hours
**Dependencies:** F.1 should complete first
**Can Run With:** F.3

**Context:**
Two domains handle battle analysis:

- `EveDmv.Api.BattleAnalysisApi`
- `EveDmv.Contexts.BattleAnalysis.Api` (acting as domain)

**Implementation Instructions:**

1. Review both domain definitions
2. Merge resources into single domain
3. Update resource registrations
4. Remove duplicate domain

**Acceptance Criteria:**

- [ ] Single battle analysis domain
- [ ] All resources properly registered
- [ ] Tests pass

---

### F.3: Remove Legacy Adapter

**Priority:** Medium
**Estimated Effort:** 2-3 hours
**Dependencies:** All other tasks complete
**Can Run With:** None (final cleanup)

**Source File:**

- Path: `lib/eve_dmv/core/infrastructure/legacy_adapter.ex`
- Lines: 428

**Implementation Instructions:**

1. Find all callers:

```bash
grep -rn "LegacyAdapter\|legacy_adapter" lib/ --include="*.ex"
```

2. Update `CharacterAnalyzer` to use Intelligence Engine directly

3. Verify no other callers exist

4. Remove legacy adapter file

5. Update any related tests

**Acceptance Criteria:**

- [ ] No references to LegacyAdapter remain
- [ ] CharacterAnalyzer uses new patterns
- [ ] File deleted
- [ ] Tests pass

---

## Execution Order

### Phase 1 (Parallel - Days 1-3)

Execute all tasks from Tracks A, B, C, D, E simultaneously.

```
┌─────────────────────────────────────────────────────────────┐
│                    PHASE 1 (PARALLEL)                       │
├──────────┬──────────┬──────────┬──────────┬────────────────┤
│ Track A  │ Track B  │ Track C  │ Track D  │ Track E        │
│ Tests    │ Split    │ API      │ Dialyzer │ Documentation  │
├──────────┼──────────┼──────────┼──────────┼────────────────┤
│ A.1      │ B.1      │ C.1      │ D.1      │ E.1            │
│ A.2      │ B.2      │ C.2      │ D.2      │ E.2            │
│ A.3      │ B.3      │ C.3      │          │ E.3            │
│ A.4      │ B.4      │          │          │                │
│ A.5      │          │          │          │                │
│ A.6      │          │          │          │                │
└──────────┴──────────┴──────────┴──────────┴────────────────┘
```

### Phase 2 (Sequential - Days 4-5)

Execute Track F tasks in order after Phase 1 completes.

```
┌─────────────────────────────────────────────────────────────┐
│                  PHASE 2 (SEQUENTIAL)                       │
├─────────────────────────────────────────────────────────────┤
│ F.1: Consolidate Duplicate Resources                        │
│                    ↓                                        │
│ F.2: Consolidate Battle Analysis Domains                    │
│                    ↓                                        │
│ F.3: Remove Legacy Adapter                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Validation Checklist

After all tasks complete:

```bash
# Run full test suite
mix test

# Run dialyzer
mix dialyzer

# Check formatting
mix format --check-formatted

# Run credo
mix credo --strict

# Generate docs
mix docs

# Run quality check script
./scripts/quality_check.sh
```

---

## Success Metrics

| Metric                 | Before | Target |
| ---------------------- | ------ | ------ |
| Test files             | 114    | 120+   |
| Files >2000 lines      | 3      | 0      |
| Files >1000 lines      | 32     | 28     |
| API modules >200 lines | 9      | 6      |
| Active dialyzer errors | 6      | 0      |
| Functions without @doc | 100+   | 47     |

---

_Generated from CODE_REVIEW_SUMMARY.md_
_Ready for parallel AI assistant execution_
