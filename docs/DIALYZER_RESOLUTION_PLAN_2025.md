# Dialyzer Resolution Plan 2025 (Revised)

## Current Status
- **Total Errors**: 1,084 (after recent API fixes)
- **Target**: <200 errors  
- **Approach**: 5 parallel workstreams focused on high-impact files

## Error Type Distribution (Updated)
- pattern_match: 36 (3.3%)
- no_return: 33 (3.0%)
- guard_fail: 21 (1.9%)
- call: 21 (1.9%)
- pattern_match_cov: 14 (1.3%)
- Other: ~959 (88.5%)

## Critical Finding
After recent Ash API fixes, the error profile has changed significantly:
1. Most `unknown_function` errors have been resolved
2. Focus now shifts to logic errors: pattern_match, no_return, guard_fail
3. A small number of high-impact files contain most errors

---

## 5 Workstreams - Revised Distribution

### Workstream A: Core Infrastructure & Platform (Target: 152 errors)
**Actual Error Count**: 152 errors
**Directories**:
- `lib/eve_dmv/platform/` 
- `lib/eve_dmv/external/` 
- `lib/eve_dmv/cache/`

**Priority Focus**:
1. Fix database repository pattern matches
2. Resolve external client error handling
3. Clean up platform utilities

**Key Files**:
- `lib/eve_dmv/platform/database/killmail_repository.ex` (21 errors)
- `lib/eve_dmv/integrations/ship_intelligence_bridge.ex` (20 errors)

### Workstream B: Web Interface (Target: 36 errors)
**Actual Error Count**: 36 errors
**Directories**:
- `lib/eve_dmv_web/live/`
- `lib/eve_dmv_web/components/`
- `lib/eve_dmv_web/controllers/`

**Priority Focus**:
1. Fix LiveView handle_event pattern matches
2. Resolve component function signatures
3. Clean up controller error handling

**Key Areas**:
- LiveView pattern matching issues
- Component callback patterns
- Controller response handling

### Workstream C: Intelligence & Analysis Contexts (Target: 487 errors - HIGHEST PRIORITY)
**Actual Error Count**: 487 errors (45% of total)
**Directories**:
- `lib/eve_dmv/contexts/intelligence/`
- `lib/eve_dmv/contexts/threat_surveillance/`
- `lib/eve_dmv/contexts/combat_intelligence/`
- `lib/eve_dmv/contexts/surveillance/`

**Priority Focus**:
1. **CRITICAL**: Fix top error files first
2. Resolve pattern_match errors in analysis engines
3. Fix no_return in scoring functions

**Key Files (High Impact)**:
- `lib/eve_dmv/contexts/intelligence/core/historical_trend_analysis.ex` (47 errors)
- `lib/eve_dmv/contexts/intelligence/core/network_analysis_engine.ex` (41 errors)
- `lib/eve_dmv/contexts/intelligence/core/behavioral_pattern_analyzer.ex` (38 errors)
- `lib/eve_dmv/contexts/threat_surveillance/domain/threat_analysis_service.ex` (36 errors)
- `lib/eve_dmv/contexts/threat_surveillance/domain/behavioral_pattern_analyzer.ex` (32 errors)

### Workstream D: Battle & Combat Contexts (Target: 157 errors)
**Actual Error Count**: 157 errors
**Directories**:
- `lib/eve_dmv/contexts/battle_analysis/`
- `lib/eve_dmv/contexts/combat/`
- `lib/eve_dmv/contexts/battle_sharing/`

**Priority Focus**:
1. Fix battle sharing tactical highlights (34 errors)
2. Resolve combat analysis threat assessment (29 errors)
3. Clean up battle detection functions

**Key Files**:
- `lib/eve_dmv/contexts/battle_sharing/domain/tactical_highlight_manager.ex` (34 errors)
- `lib/eve_dmv/contexts/combat_analysis/domain/threat_assessment_engine.ex` (29 errors)

### Workstream E: Operations & Remaining Contexts (Target: 115 errors)
**Actual Error Count**: 115 errors
**Directories**:
- `lib/eve_dmv/contexts/wormhole_operations/`
- `lib/eve_dmv/contexts/corporation*/`
- `lib/eve_dmv/contexts/fleet_operations/`
- Root level files and utilities

**Priority Focus**:
1. Fix wormhole recruitment vetter (35 errors)
2. Resolve ship stats engine (22 errors)
3. Clean up utility analyzers

**Key Files**:
- `lib/eve_dmv/contexts/wormhole_operations/domain/recruitment_vetter.ex` (35 errors)
- `lib/eve_dmv/utilities/analyzers/ship_stats_engine.ex` (22 errors)

---

## Prioritized Approach by Error Type (Revised)

### Phase 1: High-Impact Files (Week 1)
**Goal**: Fix the top 15 files with most errors (reduces ~400 errors)

**CRITICAL FILES** (Fix these first):
- `historical_trend_analysis.ex` (47 errors) - **Workstream C**
- `network_analysis_engine.ex` (41 errors) - **Workstream C**
- `behavioral_pattern_analyzer.ex` (38 errors) - **Workstream C**
- `threat_analysis_service.ex` (36 errors) - **Workstream C**
- `recruitment_vetter.ex` (35 errors) - **Workstream E**
- `tactical_highlight_manager.ex` (34 errors) - **Workstream D**

**Focus**: Fix pattern_match and no_return errors in these files

### Phase 2: Pattern Match & Guard Errors (Week 2-3)
**Goal**: Fix logical errors across all workstreams

1. **Pattern Match Errors** (36 total)
   - Fix impossible pattern matches
   - Add catch-all clauses for exhaustiveness
   - Review case statement coverage

2. **Guard Fail Errors** (21 total)
   - Fix guard clauses that can never succeed
   - Review guard logic and conditions
   - Simplify complex guard expressions

3. **Pattern Match Coverage** (14 total)
   - Remove patterns covered by previous clauses
   - Reorder pattern matching for better coverage

### Phase 3: Function Call & Logic Errors (Week 4)
**Goal**: Fix remaining call and no_return errors

1. **Call Errors** (21 total)
   - Fix function calls that will not succeed
   - Review function signatures and arguments
   - Fix dependency issues

2. **No Return Errors** (33 total)
   - Fix functions with no local return
   - Review anonymous function usage
   - Fix infinite recursion patterns

### Phase 4: Final Cleanup (Week 5)
**Goal**: Get under 200 errors using targeted fixes

1. **Workstream Priority Order**:
   - **Workstream C** (487 errors) - All hands focus
   - **Workstream D** (157 errors) - Secondary priority
   - **Workstream A** (152 errors) - Infrastructure cleanup
   - **Workstream E** (115 errors) - Operations
   - **Workstream B** (36 errors) - Quick wins

2. **Use @dialyzer annotations sparingly** for unfixable issues
3. **Document remaining issues** for future architectural decisions

---

## Coordination Guidelines

### Daily Process
1. **Morning Sync**
   - Check dialyzer_current.txt for your workstream's errors
   - Identify files to work on today
   - Check for any cross-workstream dependencies

2. **Work Pattern**
   - Fix 10-20 errors at a time
   - Run `mix compile --warnings-as-errors` after each batch
   - Commit with clear messages: "fix(dialyzer): resolve unknown_function in [module]"

3. **End of Day**
   - Push all commits to branch
   - Update workstream progress in shared doc
   - Flag any blockers for tomorrow

### Weekly Milestones (Revised)
- **Week 1**: 1,084 → 600 errors (44% reduction via high-impact files)
- **Week 2**: 600 → 400 errors (pattern match & guard fixes)
- **Week 3**: 400 → 300 errors (remaining logic errors)
- **Week 4**: 300 → 250 errors (function call fixes)
- **Week 5**: 250 → <200 errors (final cleanup & @dialyzer annotations)

---

## Success Metrics (Revised)

### Per Workstream Targets
- **Workstream A**: 152 → 30 errors (80% reduction)
- **Workstream B**: 36 → 5 errors (86% reduction) 
- **Workstream C**: 487 → 100 errors (79% reduction) - **CRITICAL**
- **Workstream D**: 157 → 35 errors (78% reduction)
- **Workstream E**: 115 → 25 errors (78% reduction)

### Daily Tracking
Each workstream should track:
1. **High-impact files** completed (from top 15 list)
2. **Error type breakdown** (pattern_match, no_return, guard_fail, call)
3. **Blocker files** that need architectural changes
4. **Quick wins** (files with <5 errors that can be fixed rapidly)

### Overall Progress Timeline
- **Week 1**: 1,084 → 600 errors (focus: critical files)
- **Week 2**: 600 → 400 errors (focus: pattern logic)
- **Week 3**: 400 → 300 errors (focus: guard clauses)
- **Week 4**: 300 → 250 errors (focus: call errors)
- **Week 5**: 250 → <200 errors (focus: final cleanup)

---

## Common Fixes Reference (Updated)

### Pattern Match Errors
```elixir
# Wrong - impossible pattern
case %{status: :ok} do
  %{status: :error} -> "error"  # This can never match
  %{status: :ok} -> "ok"
end

# Right - exhaustive patterns
case %{status: :ok} do
  %{status: :ok} -> "ok"
  %{status: :error} -> "error"
  _ -> "unknown"  # Catch-all
end
```

### Guard Fail Errors  
```elixir
# Wrong - guard can never succeed
def process(value) when is_integer(value) and is_binary(value) do
  # is_integer AND is_binary can never both be true
end

# Right - fix guard logic
def process(value) when is_integer(value) or is_binary(value) do
  # One or the other can be true
end
```

### No Return Errors
```elixir
# Wrong - anonymous function with no return
fn -> 
  Logger.info("Processing...")
  # Missing return value
end

# Right - explicit return
fn -> 
  Logger.info("Processing...")
  :ok  # Return a value
end
```

### Call Errors
```elixir
# Wrong - function signature mismatch
def analyze(data, opts \\ [])
analyze(data, callback, opts)  # Too many args

# Right - fix function call
analyze(data, opts)  # Correct number of args
```

---

## Emergency Procedures

If dialyzer errors increase significantly:
1. Stop all work immediately
2. Identify the commit that introduced errors
3. Revert if necessary
4. Coordinate fix across workstreams

Remember: The goal is steady progress, not perfection. Use @dialyzer annotations sparingly for truly unfixable issues.