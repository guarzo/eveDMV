# Dialyzer Resolution Plan 2025

## Current Status
- **Total Errors**: 5,033 (significantly higher than previous estimate)
- **Target**: <200 errors  
- **Approach**: 5 parallel workstreams with clear boundaries

## Error Type Distribution
- unknown_function: 3,786 (75%)
- unused_fun: 503 (10%)
- pattern_match: 154 (3%)
- no_return: 134 (3%)
- unknown_type: 117 (2%)
- callback_info_missing: 111 (2%)
- Other: 228 (5%)

## Critical Finding
The majority of errors (75%) are `unknown_function` - these are often caused by:
1. Missing Ash Framework function definitions
2. Incorrect API domain usage patterns
3. Missing imports/aliases

---

## 5 Workstreams - Updated Division

### Workstream A: Core Infrastructure & Platform (Target: ~1,000 errors)
**Directories**:
- `lib/eve_dmv/platform/` (500+ errors)
- `lib/eve_dmv/external/` (200+ errors)  
- `lib/eve_dmv/cache/` (100+ errors)
- Root `lib/eve_dmv/*.ex` files (172 errors)

**Priority Focus**:
1. Fix unknown_function errors in API modules first
2. Resolve callback_info_missing in GenServers
3. Clean up unused functions

**Key Files**:
- `lib/eve_dmv/api.ex` - Central API with many unknown_function errors
- `lib/eve_dmv/platform/database/` - 271 errors
- `lib/eve_dmv/external/killmails/` - 68 errors

### Workstream B: Web Interface (Target: ~1,300 errors)
**Directories**:
- `lib/eve_dmv_web/live/` (546 errors)
- `lib/eve_dmv_web/components/` (537 errors)
- `lib/eve_dmv_web/controllers/` (183 errors)
- `lib/eve_dmv_web/live/helpers/` (77 errors)

**Priority Focus**:
1. Fix LiveView handle_event/handle_info unknown_function errors
2. Resolve component function signatures
3. Clean up unused view helpers

**Key Areas**:
- LiveView modules with missing callbacks
- Component function contracts
- API controller response types

### Workstream C: Intelligence & Analysis Contexts (Target: ~1,000 errors)
**Directories**:
- `lib/eve_dmv/contexts/intelligence/` (258+ errors)
- `lib/eve_dmv/contexts/threat_surveillance/` (99 errors)
- `lib/eve_dmv/contexts/combat_intelligence/` (74 errors)
- `lib/eve_dmv/contexts/intelligence_infrastructure/` (65 errors)
- `lib/eve_dmv/contexts/surveillance/` (71 errors)

**Priority Focus**:
1. Fix pattern_match errors in analysis engines
2. Resolve no_return in scoring functions
3. Clean up unused analysis functions

### Workstream D: Battle & Combat Contexts (Target: ~900 errors)
**Directories**:
- `lib/eve_dmv/contexts/battle_analysis/` (200+ errors)
- `lib/eve_dmv/contexts/combat/` (150+ errors)
- `lib/eve_dmv/contexts/battle_sharing/` (100+ errors)
- `lib/eve_dmv/contexts/combat_analysis/` (100+ errors)

**Priority Focus**:
1. Fix Ash resource unknown_function errors
2. Resolve analyzer pattern matches
3. Clean up battle detection functions

### Workstream E: Operations & Remaining Contexts (Target: ~800 errors)
**Directories**:
- `lib/eve_dmv/contexts/wormhole_operations/` (72+ errors)
- `lib/eve_dmv/contexts/corporation*/` (100+ errors)
- `lib/eve_dmv/contexts/fleet_operations/` (50+ errors)
- All remaining contexts and modules

**Priority Focus**:
1. Fix domain API usage patterns
2. Resolve service function contracts  
3. Clean up operation analyzers

---

## Prioritized Approach by Error Type

### Phase 1: Unknown Function Errors (Weeks 1-3)
**Goal**: Reduce unknown_function errors from 3,786 to <500

1. **Ash API Pattern Fixes** (Week 1)
   - Fix all `Ash.read(query, domain: Api)` → `Api.read(query)`
   - Fix all `Ash.create/update/destroy` patterns
   - Add missing imports and aliases

2. **LiveView Callbacks** (Week 2)
   - Add missing handle_event/3 implementations
   - Add missing handle_info/2 implementations
   - Fix mount/3 return types

3. **GenServer Callbacks** (Week 3)
   - Add @impl true annotations
   - Fix init/1 return types
   - Add missing callback implementations

### Phase 2: Core Error Types (Weeks 4-5)
**Goal**: Fix pattern_match, no_return, and callback errors

1. **Pattern Match Errors** (154 total)
   - Fix case statement exhaustiveness
   - Add catch-all clauses where appropriate
   - Fix function head mismatches

2. **No Return Errors** (134 total)
   - Fix infinite loops/recursion
   - Add proper return values
   - Fix unreachable code

3. **Callback Errors** (111 total)
   - Implement missing behaviour callbacks
   - Fix callback signatures
   - Add proper typespec annotations

### Phase 3: Cleanup (Weeks 6-7)
**Goal**: Remove unused functions and fix remaining errors

1. **Unused Functions** (503 total)
   - Remove genuinely unused private functions
   - Mark intentionally unused with @compile {:nowarn_unused_function, ...}
   - Export functions that should be public

2. **Type Errors** (117 unknown_type + others)
   - Fix invalid typespecs
   - Add missing type definitions
   - Resolve contract mismatches

### Phase 4: Final Push (Week 8)
**Goal**: Get under 200 errors using @dialyzer annotations

1. Use @dialyzer :no_match for unfixable pattern matches
2. Use @dialyzer :no_return for intentional no-returns
3. Document remaining issues for future work

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

### Weekly Milestones
- Week 1: 50% reduction in unknown_function errors
- Week 2: All LiveView callbacks fixed
- Week 3: All GenServer issues resolved
- Week 4: Pattern match errors eliminated
- Week 5: No return errors fixed
- Week 6: Unused functions cleaned up
- Week 7: Type errors resolved
- Week 8: Final cleanup to <200 errors

---

## Success Metrics

### Per Workstream
Each workstream should track:
1. Starting error count
2. Daily error reduction
3. Types of errors fixed
4. Blocking issues encountered

### Overall Progress
- Week 1: 5,033 → 3,500 errors
- Week 2: 3,500 → 2,500 errors
- Week 3: 2,500 → 1,500 errors
- Week 4: 1,500 → 1,000 errors
- Week 5: 1,000 → 600 errors
- Week 6: 600 → 400 errors
- Week 7: 400 → 250 errors
- Week 8: 250 → <200 errors

---

## Common Fixes Reference

### Unknown Function - Ash API
```elixir
# Wrong
Ash.read(query, domain: Api)

# Right
Api.read(query)
```

### Unknown Function - LiveView
```elixir
# Add missing callback
@impl true
def handle_event("event_name", params, socket) do
  {:noreply, socket}
end
```

### Pattern Match
```elixir
# Add catch-all clause
case result do
  {:ok, value} -> value
  {:error, reason} -> nil
  _ -> nil  # Add this
end
```

### Unused Function
```elixir
# Option 1: Remove the function
# Option 2: Make it public
# Option 3: Suppress warning
@compile {:nowarn_unused_function, [function_name: 1]}
```

---

## Emergency Procedures

If dialyzer errors increase significantly:
1. Stop all work immediately
2. Identify the commit that introduced errors
3. Revert if necessary
4. Coordinate fix across workstreams

Remember: The goal is steady progress, not perfection. Use @dialyzer annotations sparingly for truly unfixable issues.