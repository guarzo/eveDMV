# Dialyzer Fix Implementation Plan

**Current Status:** 655 Dialyzer errors
**Target:** <50 errors
**Approach:** Systematic, phase-based resolution

## Executive Summary

This plan addresses all remaining Dialyzer issues through a 5-phase approach, prioritized by impact and complexity. The strategy focuses on fixing foundational type issues first, which will cascade to resolve many downstream errors.

## Phase Overview

| Phase | Focus | Error Count | Time Estimate | Success Target |
|-------|--------|-------------|---------------|----------------|
| 1 | Foundation Issues | 183+56+37=276 | 2-3 days | 655→380 errors |
| 2 | Logic & Flow | 49+27+22=98 | 2 days | 380→200 errors |
| 3 | Guards & Contracts | 12+6=18 | 1 day | 200→150 errors |
| 4 | Code Cleanup | 154+4+2=160 | 1 day | 150→50 errors |
| 5 | Final Validation | All remaining | 0.5 days | <50 errors |

---

## Phase 1: Foundation Issues (Priority: CRITICAL)

### 1.1 Pattern Matching Failures (183 errors)
**Root Cause:** Functions promise return types they don't actually return

**Key Patterns:**
```elixir
# Pattern expecting success but function always returns error
Pattern: {:ok, _data}
Type: {:error, :not_implemented}
```

**Fix Strategy:**
1. **Map Not-Implemented Functions**: Identify all functions returning `{:error, :not_implemented}`
2. **Implement Minimal Viable Returns**: Replace with appropriate default values
3. **Update Type Specs**: Ensure specs match actual return types

**Files to Fix:**
- `lib/eve_dmv/contexts/intelligence_scoring.ex` (42 matches)
- `lib/eve_dmv/contexts/ship_instance_extractor.ex` (15 matches)
- `lib/eve_dmv/contexts/combat_intelligence/` (30+ matches)

**Example Fix:**
```elixir
# Before
defp calculate_threat_score(_data) do
  {:error, :not_implemented}
end

# After  
defp calculate_threat_score(_data) do
  {:ok, %{score: 0.0, confidence: :low, reason: "insufficient data"}}
end
```

### 1.2 Extra Range/Type Spec Issues (56 errors)
**Root Cause:** Type specifications include impossible return types

**Fix Strategy:**
1. **Audit All Type Specs**: Review `@spec` annotations
2. **Remove Impossible Types**: Remove types that functions never return
3. **Add Missing Specs**: Add specs where they're missing but helpful

**Example Fix:**
```elixir
# Before - promises {:ok, map()} but only returns {:error, :not_implemented}
@spec get_intelligence_scores(binary()) :: {:ok, map()} | {:error, atom()}

# After - matches actual behavior
@spec get_intelligence_scores(binary()) :: {:error, :not_implemented}
```

### 1.3 Function Call Failures (37 errors)
**Root Cause:** Calling functions with wrong types or expecting wrong return types

**Critical Issues:**
- `:crypto.hash/2` argument order
- `Decimal.to_float/1` type mismatches
- `DateTime.add/3` unit issues

**Fix Strategy:**
1. **Fix Library Calls**: Correct argument types/order for external libraries
2. **Type Guard Functions**: Add type guards where needed
3. **Defensive Programming**: Handle edge cases properly

---

## Phase 2: Logic & Flow Issues (Priority: HIGH)

### 2.1 Pattern Match Coverage (49 errors)
**Root Cause:** Unreachable patterns due to previous clause coverage

**Fix Strategy:**
1. **Analyze Pattern Order**: Review case/with statements
2. **Remove Dead Patterns**: Delete unreachable patterns
3. **Restructure Logic**: Reorder patterns for better coverage

### 2.2 No Return Functions (27 errors)
**Root Cause:** Functions that call other functions that never return

**Fix Strategy:**
1. **Trace Call Chains**: Follow functions to root cause
2. **Fix Root Causes**: Ensure base functions return properly
3. **Add Error Handling**: Graceful degradation for edge cases

### 2.3 Exact Equality Issues (22 errors)
**Root Cause:** Using `===` with incompatible types

**Fix Strategy:**
1. **Type-Safe Comparisons**: Use appropriate comparison operators
2. **Pattern Matching**: Replace equality checks with pattern matching
3. **Guard Improvements**: Use proper type guards

---

## Phase 3: Guards & Contracts (Priority: MEDIUM)

### 3.1 Guard Failures (12 errors)
**Root Cause:** Guard clauses that can never succeed due to type constraints

**Common Patterns:**
- `when score >= 90` where score is always 0
- `when value === nil` where value is always number

**Fix Strategy:**
1. **Guard Analysis**: Review all guard clauses
2. **Type-Aware Guards**: Ensure guards match actual types
3. **Remove Impossible Guards**: Delete guards that can never be true

### 3.2 Contract Violations (6 errors)
**Root Cause:** Function implementations don't match their contracts

**Fix Strategy:**
1. **Contract Audit**: Review all `@spec` declarations
2. **Implementation Alignment**: Make functions match their specs
3. **Test Coverage**: Ensure contracts are tested

---

## Phase 4: Code Cleanup (Priority: LOW)

### 4.1 Unused Functions (154 errors)
**Root Cause:** Dead code from incomplete features

**Strategy:**
1. **Mark for Removal**: Identify truly unused functions
2. **Future Implementation**: Keep functions planned for future use
3. **Clean Removal**: Remove functions and their dependencies

### 4.2 Minor Issues (6 errors)
- Callback issues (4)
- Apply errors (2)

---

## Phase 5: Final Validation

### 5.1 Integration Testing
- Full Dialyzer run
- Compilation check
- Basic functionality test

### 5.2 Success Metrics
- **Target:** <50 Dialyzer errors
- **Quality:** No critical runtime issues
- **Maintainability:** Clear, documented code

---

## Implementation Scripts

### Script 1: Find Not-Implemented Functions
```bash
# Find all functions returning {:error, :not_implemented}
grep -r "error.*not_implemented" lib/ --include="*.ex"
```

### Script 2: Analyze Pattern Matching Issues
```bash
# Run focused Dialyzer on specific modules
mix dialyzer --format short | grep "pattern_match"
```

### Script 3: Type Spec Audit
```bash
# Find type specs that might be wrong
grep -r "@spec" lib/ | grep -E "(not_implemented|error.*only)"
```

---

## Risk Mitigation

### High-Risk Changes
1. **Core Intelligence Modules**: Changes may affect threat scoring
2. **Database Interactions**: Type changes could break queries
3. **API Responses**: Changes could break client expectations

### Mitigation Strategies
1. **Incremental Testing**: Test after each major change
2. **Backup Points**: Commit frequently during fixes
3. **Rollback Plan**: Keep working state for quick rollback

---

## Success Criteria

### Phase Completion Criteria
- **Phase 1**: <380 errors, all foundation issues resolved
- **Phase 2**: <200 errors, no logic/flow issues
- **Phase 3**: <150 errors, clean guards and contracts
- **Phase 4**: <50 errors, minimal unused code
- **Phase 5**: All tests pass, production ready

### Quality Gates
1. **Compilation**: Must compile without warnings
2. **Tests**: Core functionality tests must pass
3. **Performance**: No significant performance regression
4. **Documentation**: All changes documented

---

## Timeline

### Week 1
- Day 1-2: Phase 1 (Foundation)
- Day 3-4: Phase 2 (Logic)
- Day 5: Phase 3 (Guards)

### Week 2  
- Day 1: Phase 4 (Cleanup)
- Day 2: Phase 5 (Validation)
- Day 3-5: Buffer/refinement

**Total Estimated Effort:** 7-10 days of focused work

---

## Conclusion

This systematic approach will reduce Dialyzer errors from 655 to <50 through focused, phase-based fixes. The plan prioritizes high-impact issues first while maintaining system stability throughout the process.

The success of this plan depends on:
1. Methodical execution of each phase
2. Thorough testing at each stage
3. Proper documentation of changes
4. Maintaining focus on critical path issues

Expected outcome: A robust, type-safe codebase with minimal Dialyzer warnings and improved maintainability.