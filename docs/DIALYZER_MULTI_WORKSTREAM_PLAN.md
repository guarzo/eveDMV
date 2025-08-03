# Dialyzer Error Resolution: Multi-Workstream Plan

## Executive Summary

Current Status: **1,901 total errors** (419 skipped)

### Error Type Breakdown
- **unused_fun**: 68 errors (35.8%)
- **pattern_match**: 8 errors (0.4%)
- **extra_range**: 8 errors (0.4%)
- **invalid_contract**: 5 errors (0.3%)
- **contract_supertype**: 4 errors (0.2%)
- **no_return**: 15 errors (0.8%)
- **call**: 10 errors (0.5%)
- **guard_fail**: 3 errors (0.2%)
- **Other errors**: ~1,180 errors (62.1%)

### Context Distribution (Top 10)
1. **intelligence**: 266 errors (14.0%)
2. **wormhole_operations**: 123 errors (6.5%)
3. **combat_intelligence**: 112 errors (5.9%)
4. **battle_analysis**: 98 errors (5.2%)
5. **market_intelligence**: 87 errors (4.6%)
6. **fleet_operations**: 76 errors (4.0%)
7. **character_intelligence**: 65 errors (3.4%)
8. **surveillance**: 54 errors (2.8%)
9. **corporation_intelligence**: 43 errors (2.3%)
10. **platform**: 98 errors (5.2%)

## Multi-Workstream Plan

### Workstream Alpha: Pattern Match & Type Specification Errors
**Size**: ~450 errors
**Priority**: High
**Duration**: 3 days

#### Focus Areas
1. **Pattern Match Errors** (8 explicit + ~200 implicit)
   - Fix `{:ok, _}` patterns that can never match error tuples
   - Update case statements with missing error clauses
   - Add proper error handling for Ash.Query results

2. **Type Specification Errors** (17 explicit + ~150 implicit)
   - Fix extra_range errors where specs are too broad
   - Correct invalid_contract errors where specs don't match implementations
   - Update contract_supertype issues

3. **Guard Failures** (3 explicit + ~50 implicit)
   - Fix guard clauses that can never succeed
   - Remove impossible pattern matches

#### Key Files
- `lib/eve_dmv/contexts/battle_analysis/services/battle_service.ex`
- `lib/eve_dmv/contexts/combat/services/battle_sharing_service.ex`
- `lib/eve_dmv/contexts/wormhole_operations/domain/home_defense_analyzer.ex`
- `lib/eve_dmv/contexts/intelligence/core/character_analyzer.ex`

### Workstream Beta: Unused Functions & Dead Code
**Size**: ~680 errors
**Priority**: Medium
**Duration**: 2 days

#### Focus Areas
1. **Unused Private Functions** (68 explicit + ~600 estimated)
   - Remove functions that are never called
   - Convert some to public if they should be exposed
   - Consolidate duplicate functionality

2. **Dead Code Paths**
   - Remove unreachable case clauses
   - Clean up legacy implementations

#### Key Modules
- Battle analysis helper functions
- Intelligence engine analyzers
- Wormhole operations utilities
- Combat statistics calculators

### Workstream Gamma: No Return & Call Errors
**Size**: ~320 errors
**Priority**: High
**Duration**: 3 days

#### Focus Areas
1. **No Return Functions** (15 explicit + ~150 related)
   - Fix functions that crash or have infinite loops
   - Add proper return values
   - Handle all error cases

2. **Function Call Errors** (10 explicit + ~150 related)
   - Fix incorrect function arguments
   - Update calls to match function signatures
   - Resolve DateTime.truncate(:minute) errors

#### Critical Functions
- `DateTime.truncate/2` calls with `:minute` (should be `:second`)
- `Ash.bulk_destroy/3` incorrect arguments
- Repository function calls with wrong types

### Workstream Delta: Business Logic & Domain Errors
**Size**: ~451 errors
**Priority**: Medium
**Duration**: 4 days

#### Focus Areas
1. **Intelligence Context** (266 errors)
   - Fix behavioral pattern analyzer
   - Update combat stats analyzer
   - Correct threat assessment logic

2. **Wormhole Operations** (123 errors)
   - Fix home defense analyzer patterns
   - Update recruitment vetter logic
   - Correct fleet optimizer

3. **Combat Intelligence** (112 errors)
   - Fix battle phase analyzer
   - Update tactical pattern detector
   - Correct performance calculator

### Workstream Epsilon: Infrastructure & Platform
**Size**: ~200 errors
**Priority**: Low
**Duration**: 2 days

#### Focus Areas
1. **Database Layer** (50 errors)
   - Fix repository function calls
   - Update query builders
   - Correct cache helpers

2. **Monitoring & Telemetry** (48 errors)
   - Fix performance dashboard
   - Update query monitor
   - Correct connection pool monitor

3. **LiveView Components** (102 errors)
   - Fix pattern matches in mount callbacks
   - Update handle_event signatures
   - Correct socket assigns

## Implementation Strategy

### Week 1 (Days 1-5)
- **Alpha Team**: Start with pattern match and type specification errors
- **Gamma Team**: Begin fixing no return and call errors in parallel
- **Daily sync**: Share common patterns and solutions

### Week 2 (Days 6-10)
- **Beta Team**: Remove unused functions and dead code
- **Delta Team**: Fix business logic errors in intelligence and operations
- **Epsilon Team**: Clean up infrastructure issues

### Week 3 (Days 11-14)
- **All Teams**: Final cleanup and verification
- **Integration testing**: Ensure fixes don't introduce new errors
- **Documentation**: Update specs and add missing @doc entries

## Common Patterns to Fix

### 1. DateTime.truncate Error
```elixir
# Wrong
DateTime.truncate(datetime, :minute)

# Correct
datetime |> DateTime.truncate(:second) |> DateTime.add(-rem(datetime.second, 60), :second)
```

### 2. Pattern Match on Error Tuples
```elixir
# Wrong
case get_battle(id) do
  {:ok, battle} -> process(battle)
end

# Correct
case get_battle(id) do
  {:ok, battle} -> process(battle)
  {:error, reason} -> {:error, reason}
end
```

### 3. Ash.bulk_destroy Arguments
```elixir
# Wrong
Ash.bulk_destroy(query, :destroy, domain: Api)

# Correct
query
|> Ash.Query.for_destroy(:destroy)
|> Ash.bulk_destroy(domain: Api)
```

### 4. Type Specification Alignment
```elixir
# Wrong
@spec delete_battle(String.t()) :: :ok | {:error, any()}
def delete_battle(battle_id) do
  {:error, :not_found}  # Never returns :ok
end

# Correct
@spec delete_battle(String.t()) :: {:error, atom()}
```

## Success Metrics
- **Day 5**: Pattern match and type errors reduced by 90%
- **Day 10**: Unused functions eliminated, no return errors fixed
- **Day 14**: Total errors < 200, all critical paths error-free

## Risk Mitigation
1. **Regression Testing**: Run full test suite after each major fix
2. **Incremental Commits**: Small, focused commits for easy rollback
3. **Code Review**: Cross-team reviews for complex fixes
4. **Documentation**: Update specs and add comments for tricky fixes