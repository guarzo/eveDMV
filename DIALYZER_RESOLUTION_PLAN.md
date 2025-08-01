# Dialyzer Issues Resolution Plan

## Overview

Based on the Dialyzer analysis showing 1,949 errors with 319 skipped, this document outlines a comprehensive multi-workstream approach to resolve all type checking issues in the EVE DMV codebase.

## Current Status
- **Total Errors**: 1,949
- **Skipped Errors**: 319  
- **Unnecessary Skips**: 0
- **Analysis Time**: 1m21.81s

## Workstream Breakdown

### **Workstream 1: Undefined Module Calls (HIGH PRIORITY)**

**Issue**: References to modules that don't exist in the codebase.

**Examples**:
- `FleetCompositionAnalyzer.analyze_enhanced_fleet_composition/1` - Missing module
- `FleetPilotAnalyzer.get_available_pilots/1` - Missing module  
- `FleetComposition.create/1` - Missing domain module
- Various fleet and wormhole operation analyzers

**Impact**: These cause runtime crashes when the code paths are executed.

**Resolution Strategy**:
1. Identify all missing modules from Dialyzer output
2. Determine if modules should be implemented or calls should be removed
3. For placeholder implementations, remove calls following clean codebase principles
4. For required functionality, implement minimal viable modules with real data

**Files Affected**:
- `lib/eve_dmv/contexts/wormhole_operations/analyzers/wh_fleet_analyzer.ex`
- `lib/eve_dmv/contexts/wormhole_operations/analyzers/wh_doctrine_manager.ex`
- `lib/eve_dmv/contexts/wormhole_operations/analyzers/wh_compatibility_analyzer.ex`

### **Workstream 2: Undefined Function Calls (HIGH PRIORITY)**

**Issue**: Calls to functions that don't exist in existing modules.

**Examples**:
- `CharacterRepository.get_characters_by_ids/1` - Function doesn't exist
- `CharacterRepository.get_character_ship_usage/1` - Function doesn't exist
- `CharacterRepository.get_character_ship_stats/1` - Function doesn't exist
- `EsiCache.get_structure/1` - Removed with duplicate module cleanup
- `ShipTypes.get_ship_type/1` - Function doesn't exist
- `Enum.sum/2` - Using wrong arity (should be `sum/1`)

**Impact**: Runtime errors when these code paths are executed.

**Resolution Strategy**:
1. Audit all repository modules for missing functions
2. Implement missing functions with real database queries
3. Fix incorrect function arities (e.g., `Enum.sum/2` → `Enum.sum/1`)
4. Add proper type specs to all repository functions

**Files Affected**:
- `lib/eve_dmv/platform/database/character_repository.ex`
- `lib/eve_dmv/static_data/ship_types.ex`
- `lib/eve_dmv/contexts/combat/services/combat_log_parser.ex`
- `lib/eve_dmv/utilities/analyzers/asset_analyzer.ex`

### **Workstream 3: Pattern Match Coverage (MEDIUM PRIORITY)**

**Issue**: Pattern matches that can never be reached due to complete coverage by previous clauses.

**Examples**:
```elixir
# In profile_live.ex:102 - :variable_ can never match
case some_function() do
  {:ok, %{...}} -> # This matches everything
  :variable_ -> # This can never be reached
end
```

**Impact**: Dead code that indicates logic errors or unnecessary complexity.

**Resolution Strategy**:
1. Review all pattern matching in LiveView modules
2. Remove unreachable patterns
3. Simplify pattern matching logic where possible
4. Add proper error handling for expected failure cases

**Files Affected**:
- `lib/eve_dmv_web/live/profile_live.ex`
- `lib/eve_dmv_web/live/surveillance_live/profile_service.ex`

### **Workstream 4: Guard Failures (MEDIUM PRIORITY)**

**Issue**: Guard tests that can never succeed due to type mismatches.

**Examples**:
```elixir
# Guard testing if exception struct is binary - impossible
when is_binary(%{__exception__: true, __struct__: atom(), ...})
```

**Impact**: Logic errors in error handling that may mask real issues.

**Resolution Strategy**:
1. Review guard conditions in error handling code
2. Fix type mismatches in guard tests  
3. Ensure proper error pattern matching
4. Add tests for error handling paths

**Files Affected**:
- `lib/eve_dmv_web/live/surveillance_live/profile_service.ex`

### **Workstream 5: Type Mismatches (MEDIUM PRIORITY)**

**Issue**: Functions returning different types than expected, pattern matching on impossible types.

**Examples**:
- Mix task pattern matching on `false` when type is always `true`
- Return type inconsistencies across modules
- Struct field type mismatches

**Impact**: Potential runtime errors and maintainability issues.

**Resolution Strategy**:
1. Add comprehensive type specs to all public functions
2. Fix return type inconsistencies
3. Review and fix Mix task implementations
4. Ensure consistent error return patterns

**Files Affected**:
- `lib/mix/tasks/eve.partition_manager.ex`
- Various context modules with inconsistent return types

### **Workstream 6: Unused Variables (LOW PRIORITY)**

**Issue**: Variables that are declared but never used.

**Examples**:
```elixir
def handle_info(msg, state) do  # 'msg' is unused
```

**Impact**: Code clarity and maintainability (no functional impact).

**Resolution Strategy**:
1. Prefix unused variables with underscore: `_msg`
2. Remove truly unnecessary variable assignments
3. Document intentionally unused parameters
4. Set up linting rules to catch future occurrences

## Implementation Timeline

### Phase 1: Critical Fixes (Week 1-2)
- **Workstream 1**: Fix all undefined module calls
- **Workstream 2**: Implement missing repository functions

### Phase 2: Logic Fixes (Week 3)
- **Workstream 3**: Fix pattern matching coverage issues  
- **Workstream 4**: Fix guard test failures

### Phase 3: Polish (Week 4)
- **Workstream 5**: Fix type mismatches and specs
- **Workstream 6**: Clean up unused variables

## Success Metrics

- **Target**: Zero Dialyzer errors
- **Intermediate Goal**: Under 100 errors after Phase 1
- **Quality Gate**: All high-priority issues resolved before Phase 2

## Parallel Execution Strategy

**Workstreams 1 & 2** can be worked simultaneously as they affect different modules.

**Workstreams 3 & 4** should be done after 1 & 2 to avoid fixing issues that may be resolved by missing implementations.

**Workstreams 5 & 6** are cleanup tasks that can be done in parallel with testing of earlier fixes.

## Notes

- Follow the clean codebase principles: remove placeholder implementations rather than fixing them
- All fixes should include appropriate tests
- Document any intentional Dialyzer suppressions in `.dialyzer_ignore.exs`
- Run Dialyzer incrementally after each workstream to track progress