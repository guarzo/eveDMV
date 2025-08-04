# Dialyzer Zero-Error Plan 2025

## Executive Summary
**Goal**: Achieve 0 dialyzer errors across the entire codebase  
**Current State**: 853 errors → 561 errors (after excluding unused_fun)  
**Timeline**: 4 weeks with 5 parallel workstreams  
**Approach**: Configuration optimization + systematic error resolution

---

## Phase 0: Configuration & Setup (Day 1)

### 1. Update Dialyzer Configuration
```elixir
# mix.exs
dialyzer: [
  plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
  plt_add_apps: [:mix, :ex_unit],
  plt_core_path: "priv/plts/core.plt",
  list_unused_filters: true,
  # Exclude unused function warnings
  flags: [:error_handling, :underspecs, :no_unused],
  paths: ["_build/#{Mix.env()}/lib/eve_dmv/ebin"],
  check_plt: false,
  ignore_warnings: ".dialyzer_ignore.exs"
]
```

### 2. Update GitHub Workflow
```yaml
# .github/workflows/ci.yml
- name: Run Dialyzer
  run: |
    mix dialyzer --format short
    # Temporarily allow any number of errors during transition
    # Will be removed once we reach 0
```

### 3. Baseline Metrics
- **Total Errors**: 561 (after excluding unused_fun)
- **Error Distribution**:
  - pattern_match: 178 (31.7%)
  - no_return: 121 (21.6%)
  - call: 75 (13.4%)
  - contract_supertype: 51 (9.1%)
  - extra_range: 46 (8.2%)
  - guard_fail: 26 (4.6%)
  - pattern_match_cov: 24 (4.3%)
  - invalid_contract: 24 (4.3%)
  - unknown_type: 5 (0.9%)
  - Other: 11 (2.0%)

---

## 5 Workstreams - Zero Error Distribution

### Workstream A: Infrastructure & Platform (147 → 0 errors)
**Team Size**: 2 developers  
**Timeline**: 4 weeks  

**Scope**:
- `lib/eve_dmv/platform/` (~60 errors)
- `lib/eve_dmv/external/` (~40 errors)
- `lib/eve_dmv/cache/` (~30 errors)
- `lib/eve_dmv/integrations/` (~17 errors)

**Week-by-Week Goals**:
- Week 1: Fix pattern_match errors (40 errors)
- Week 2: Fix no_return and call errors (35 errors)
- Week 3: Fix type-related errors (40 errors)
- Week 4: Fix remaining and add @dialyzer where needed (32 errors)

**Key Files**:
- `platform/database/killmail_repository.ex` (21 errors)
- `integrations/ship_intelligence_bridge.ex` (15 errors)
- External API clients and cache implementations

### Workstream B: Web Interface (35 → 0 errors)
**Team Size**: 1 developer  
**Timeline**: 2 weeks (then assists other workstreams)

**Scope**:
- `lib/eve_dmv_web/live/` (~15 errors)
- `lib/eve_dmv_web/components/` (~10 errors)
- `lib/eve_dmv_web/controllers/` (~10 errors)

**Week-by-Week Goals**:
- Week 1: Fix all pattern_match and no_return (20 errors)
- Week 2: Fix remaining errors (15 errors)
- Week 3-4: Assist Workstream C

**Focus**: Quick wins - smallest workstream should finish first

### Workstream C: Intelligence & Analysis (305 → 0 errors)
**Team Size**: 3 developers  
**Timeline**: 4 weeks

**Scope**:
- `lib/eve_dmv/contexts/intelligence/` (~120 errors)
- `lib/eve_dmv/contexts/threat_surveillance/` (~100 errors)
- `lib/eve_dmv/contexts/combat_intelligence/` (~50 errors)
- `lib/eve_dmv/contexts/surveillance/` (~35 errors)

**Week-by-Week Goals**:
- Week 1: Fix top 4 files (100 errors)
  - `threat_analysis_service.ex` (39 errors)
  - `behavioral_pattern_analyzer.ex` (37 errors)
  - `performance_analyzer.ex` (28 errors)
- Week 2: Fix pattern_match errors (80 errors)
- Week 3: Fix no_return and call errors (70 errors)
- Week 4: Fix remaining type errors (55 errors)

### Workstream D: Battle & Combat (121 → 0 errors)
**Team Size**: 2 developers  
**Timeline**: 4 weeks

**Scope**:
- `lib/eve_dmv/contexts/battle_analysis/` (~50 errors)
- `lib/eve_dmv/contexts/combat/` (~40 errors)
- `lib/eve_dmv/contexts/battle_sharing/` (~31 errors)

**Week-by-Week Goals**:
- Week 1: Fix pattern_match errors (35 errors)
- Week 2: Fix no_return errors (30 errors)
- Week 3: Fix call and type errors (30 errors)
- Week 4: Fix remaining (26 errors)

**Key Files**:
- `combat_intelligence/domain/character_analyzer.ex` (22 errors)
- `battle_sharing/domain/tactical_highlight_manager.ex` (17 errors)

### Workstream E: Operations & Utilities (111 → 0 errors)
**Team Size**: 2 developers  
**Timeline**: 4 weeks

**Scope**:
- `lib/eve_dmv/contexts/wormhole_operations/` (~60 errors)
- `lib/eve_dmv/contexts/corporation*/` (~30 errors)
- `lib/eve_dmv/utilities/` (~21 errors)

**Week-by-Week Goals**:
- Week 1: Fix recruitment_vetter.ex (35 errors)
- Week 2: Fix remaining wormhole ops (25 errors)
- Week 3: Fix utilities and corporation (30 errors)
- Week 4: Fix remaining (21 errors)

---

## Weekly Milestones & Coordination

### Week 1: High-Impact Files (561 → 350 errors)
**Goal**: 38% reduction by fixing worst offenders

**All Teams Focus**:
- Each workstream fixes their worst 2-3 files
- Daily standup to share blockers
- Pattern match errors are priority

**Validation**: Run dialyzer daily, track progress

### Week 2: Pattern Match Sweep (350 → 200 errors)
**Goal**: 43% reduction, reach CI threshold

**Strategy**:
- Complete all remaining pattern_match errors
- Start on no_return errors
- Workstream B assists Workstream C

**Milestone**: CI can be configured to fail on >200 errors

### Week 3: Logic Error Cleanup (200 → 80 errors)
**Goal**: 60% reduction, momentum building

**Focus**:
- Complete no_return fixes
- Fix all call errors
- Start on type-related errors

**Critical**: No new features this week - full focus on dialyzer

### Week 4: Final Push to Zero (80 → 0 errors)
**Goal**: Complete elimination

**Tactics**:
- Fix remaining type errors
- Strategic use of @dialyzer for unfixable issues
- Code review all @dialyzer annotations
- Celebrate at 0!

---

## Success Strategies

### 1. Parallelize Aggressively
- 5 workstreams work independently
- No blocking dependencies between streams
- Share solutions in daily standups

### 2. Fix Categories, Not Files
- Week 1: Worst files
- Week 2: pattern_match errors
- Week 3: no_return/call errors  
- Week 4: Type errors & cleanup

### 3. Use @dialyzer Strategically
Guidelines for annotation use:
- Document why it's unfixable
- Get code review approval
- Track in shared spreadsheet
- Target: <50 annotations total

### 4. Maintain Momentum
- Daily progress tracking
- Public dashboard
- Celebrate milestones (500, 400, 300, 200, 100, 50, 0)
- Pizza party at 0 errors

---

## Common Fix Patterns

### Pattern Match Fixes
```elixir
# Add catch-all clauses
case result do
  {:ok, value} -> process(value)
  {:error, reason} -> handle_error(reason)
  other -> Logger.warning("Unexpected: #{inspect(other)}")
end
```

### No Return Fixes
```elixir
# Ensure all paths return
def process(data) do
  if valid?(data) do
    {:ok, transform(data)}
  else
    {:error, :invalid_data}  # Don't forget else clause!
  end
end
```

### Call Error Fixes
```elixir
# Fix function signatures
# Wrong: calling with 3 args when it takes 2
process(data, opts, callback)

# Right: combine into options
process(data, opts ++ [callback: callback])
```

### Type Contract Fixes
```elixir
# Add proper typespecs
@spec process(map()) :: {:ok, term()} | {:error, atom()}
def process(data) when is_map(data) do
  # Implementation
end
```

---

## Tracking & Metrics

### Daily Metrics
Track in shared spreadsheet:
- Total errors per workstream
- Errors fixed today
- Error types remaining
- Blockers encountered

### Weekly Reports
- Percentage complete per workstream
- Overall progress to zero
- @dialyzer annotations used
- Estimated completion date

### Success Criteria
✅ 0 dialyzer errors  
✅ <50 @dialyzer annotations  
✅ All workstreams complete  
✅ CI enforces 0 errors  
✅ Documentation updated  

---

## Post-Zero Maintenance

Once we achieve 0 errors:

1. **Update CI/CD**
   ```yaml
   - name: Run Dialyzer (Enforce Zero)
     run: mix dialyzer --format short --error-on-warning
   ```

2. **Establish Policy**
   - No PR merged with dialyzer errors
   - New code must be dialyzer-clean
   - Quarterly review of @dialyzer annotations

3. **Celebrate Success**
   - Team announcement
   - Case study blog post
   - Knowledge sharing session

---

## Risk Mitigation

### If Behind Schedule
- Borrow developers from completed workstreams
- Focus week: cancel meetings, heads-down fixing
- Consider temporary @dialyzer for complex issues
- Extend timeline by 1 week maximum

### If New Errors Appear
- Fix immediately (same day)
- Add pre-commit hook for dialyzer
- Identify root cause and prevent recurrence

### If Blocked on Architecture
- Escalate to tech lead
- Consider refactoring in separate PR
- Document as technical debt
- Use @dialyzer with TODO comment

---

## Conclusion

Achieving 0 dialyzer errors is ambitious but achievable with:
- 5 parallel workstreams
- 4 week timeline
- Clear weekly goals
- Strong coordination
- Team commitment

The investment will pay dividends in:
- Fewer production bugs
- Better type safety
- Improved code quality
- Enhanced developer confidence

Let's make EVE DMV the first major Elixir project with 0 dialyzer errors! 🚀