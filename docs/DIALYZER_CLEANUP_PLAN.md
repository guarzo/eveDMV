# Dialyzer Cleanup Implementation Plan

## Executive Summary

This plan outlines a parallel workstream approach to remove overly aggressive dialyzer ignores and fix underlying type safety issues. The goal is to reduce dialyzer errors from 1,916 to under 200 actionable warnings while improving code quality and catching real bugs.

## Current State

- **Total Dialyzer Errors:** 1,916
- **Skipped Errors:** 488
- **Unnecessary Skips:** 1
- **Overly Broad Ignore Patterns:** Multiple regex patterns hiding real issues

## Parallel Workstreams

### Workstream A: Type Specification Fixes
**Owner:** Senior Developer with strong typing experience
**Duration:** 3-5 days
**Dependencies:** None (can start immediately)

#### Scope
- Remove the overly broad supertype warning ignore: `~r"Type specification.*is a supertype of the success typing.*"`
- Fix type specifications that are too generic

#### Tasks
1. **Discovery Phase (Day 1)**
   - Run dialyzer without supertype ignore pattern
   - Catalog all affected modules and functions
   - Group by similar fix patterns

2. **Fix Common Patterns (Days 2-3)**
   - Replace `{:ok, any()}` with specific return types
   - Fix `term()` specifications with actual types
   - Resolve `String.t()` vs `binary()` mismatches
   - Update map specifications to use proper key types

3. **Complex Type Fixes (Days 4-5)**
   - Fix union types that are too broad
   - Add missing type aliases for complex types
   - Update specs for functions with multiple return patterns

#### Success Metrics
- Reduce supertype warnings by 90%
- All public API functions have accurate type specs

### Workstream B: Battle & Combat Module Fixes
**Owner:** Developer familiar with battle analysis domain
**Duration:** 2-3 days
**Dependencies:** None (can start immediately)

#### Scope
Remove pattern match ignores for:
- Timeline builder `:not_implemented` errors
- Battle sharing `:curator_unavailable` errors
- Tactical highlight manager `:battle_data_unavailable` errors

#### Tasks
1. **Timeline Builder Fixes (Day 1)**
   ```elixir
   # Current: Returns {:error, :not_implemented}
   # Fix: Implement actual timeline building or proper error handling
   ```
   - Implement missing timeline functionality
   - Or add proper error type specs if intentionally unimplemented

2. **Battle Curator Error Handling (Day 2)**
   ```elixir
   # Add missing case clauses for:
   # - {:error, :curator_unavailable}
   # - {:error, :battle_data_unavailable}
   ```
   - Add comprehensive error handling
   - Update calling functions to handle all error cases

3. **Tactical Highlight Manager (Day 3)**
   - Handle all possible data availability scenarios
   - Add fallback behavior for missing data
   - Update type specs to include all return patterns

#### Success Metrics
- Zero pattern match warnings in battle modules
- All error conditions properly handled

### Workstream C: Enum & Pattern Coverage
**Owner:** Any available developer
**Duration:** 2-3 days
**Dependencies:** None (can start immediately)

#### Scope
Fix incomplete pattern matching for:
- Corporation threat detector (`:stable` patterns)
- External group analyzer (enum patterns)
- Combat intelligence engine (`:minimal` patterns)
- Cache hit/miss patterns

#### Tasks
1. **Enum Pattern Completion (Days 1-2)**
   ```elixir
   # Example fix pattern:
   case threat_level do
     :critical -> ...
     :high -> ...
     :moderate -> ...
     :low -> ...
     :minimal -> ...
     # Add missing: :stable, :unknown
   end
   ```
   - Add complete case coverage for all enum values
   - Use `@type` to define all possible enum values
   - Add catch-all clauses where appropriate

2. **Cond Expression Fixes (Day 3)**
   - Review all cond expressions with `true` catch-all
   - Ensure all branches can actually be reached
   - Convert to case expressions where more appropriate

#### Success Metrics
- Complete pattern coverage for all enums
- No unreachable code warnings

### Workstream D: Infrastructure & Cache Patterns
**Owner:** Developer with caching experience
**Duration:** 1-2 days
**Dependencies:** Can start after initial analysis

#### Scope
- Fix cache hit/miss pattern warnings
- Update Wanderer client type specs
- Fix authentication manager patterns

#### Tasks
1. **Cache Pattern Fixes (Day 1)**
   ```elixir
   # Fix patterns like:
   # {:miss, {:ok, _}} pattern matches
   ```
   - Review cache implementation return types
   - Add proper type specs for cache operations
   - Handle all cache states properly

2. **External Client Updates (Day 2)**
   - Update Wanderer client specs
   - Fix authentication flow patterns
   - Add error handling for external service failures

#### Success Metrics
- All cache operations have correct type specs
- External service integrations properly typed

### Workstream E: Testing & Validation
**Owner:** QA/Testing specialist
**Duration:** Ongoing throughout other workstreams
**Dependencies:** Requires output from other workstreams

#### Tasks
1. **Create Dialyzer Regression Tests**
   - Set up CI job to track dialyzer error count
   - Create baseline metrics
   - Alert on regression

2. **Validate Fixes**
   - Run dialyzer after each workstream merge
   - Ensure error count decreases
   - Verify no new warnings introduced

3. **Documentation Updates**
   - Update type documentation
   - Add examples for complex types
   - Document any remaining legitimate ignores

## Coordination & Merge Strategy

### Daily Sync Points
- Morning: 15-minute standup to coordinate workstreams
- End of day: Share progress and blockers

### Merge Order
1. **Independent fixes first** (no conflicts expected)
   - Workstream D (Infrastructure)
   - Workstream C (Enums)
2. **Domain-specific fixes** (minimal overlap)
   - Workstream B (Battle modules)
3. **Broad type fixes last** (may touch many files)
   - Workstream A (Type specs)

### Conflict Resolution
- Each workstream works in separate branch
- Merge to `dialyzer-cleanup/main` branch daily
- Resolve conflicts in coordination meeting
- Final merge to main after all workstreams complete

## Final Cleanup Phase (All Workstreams)

After all workstreams complete:

1. **Update `.dialyzer_ignore.exs`**
   - Remove all overly broad patterns
   - Keep only verified false positives
   - Add specific file:line ignores if needed
   - Document why each remaining ignore exists

2. **Final Validation**
   - Run full dialyzer check
   - Verify error count < 200
   - Ensure all remaining warnings are actionable
   - Update CI thresholds

## Success Criteria

- [ ] Dialyzer errors reduced from 1,916 to < 200
- [ ] No overly broad ignore patterns remain
- [ ] All public APIs have accurate type specs
- [ ] Pattern match warnings eliminated
- [ ] CI enforcement prevents regression
- [ ] Documentation updated

## Risk Mitigation

1. **Large PR Risk**
   - Merge frequently to `dialyzer-cleanup/main`
   - Keep individual PRs under 500 lines
   - Review as work progresses

2. **Breaking Changes**
   - Type spec changes shouldn't break runtime
   - Test thoroughly in staging
   - Have rollback plan ready

3. **Timeline Slippage**
   - Workstreams are independent
   - Can merge completed work incrementally
   - Priority order: B > C > D > A > E

## Timeline

**Week 1:**
- Days 1-2: All workstreams begin discovery and implementation
- Days 3-4: First fixes merged, validation begins
- Day 5: Mid-point sync and adjustment

**Week 2:**
- Days 1-2: Complete remaining implementation
- Day 3: Final cleanup phase
- Days 4-5: Validation, documentation, and merge to main

Total Duration: 2 weeks with 4-5 developers working in parallel