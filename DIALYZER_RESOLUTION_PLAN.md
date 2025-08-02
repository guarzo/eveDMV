# Dialyzer Error Resolution Implementation Plan

## Executive Summary

Total Dialyzer errors: **1,494** (after ignoring 474)
- 840 unused functions (56%)
- 186 pattern match errors (12%)
- 178 no_return errors (12%)
- 290 other errors (20%)

## Parallel Workstreams

### Workstream Alpha: Dead Code Elimination (840 errors)
**Owner**: Team 1
**Priority**: High
**Timeline**: 3-4 days

#### Scope
Remove all unused functions across the codebase. These are functions that are never called and represent dead code.

#### Approach
1. **Automated Removal Script** (Day 1)
   - Create script to parse dialyzer output and identify unused functions
   - Generate removal commands for each function
   - Review and batch execute removals

2. **Module-by-Module Cleanup** (Days 2-3)
   - Start with highest error count modules:
     - `contexts/intelligence/core` (331 errors)
     - `contexts/corporation/core` (80 errors)
     - `contexts/wormhole_operations/domain` (77 errors)
   
3. **Validation** (Day 4)
   - Run tests after each module cleanup
   - Ensure no runtime dependencies were missed
   - Update any documentation referencing removed functions

#### Files to Focus On
```
contexts/intelligence/core/behavioral_pattern_analyzer.ex
contexts/intelligence/core/combat_stats_analyzer.ex
contexts/intelligence/core/ml_scoring_engine.ex
contexts/corporation/core/member_activity_analyzer.ex
contexts/wormhole_operations/domain/analyzers/wh_fleet_analyzer.ex
```

### Workstream Beta: Type Specification Fixes (200 errors)
**Owner**: Team 2
**Priority**: High
**Timeline**: 3-4 days

#### Scope
Fix invalid contracts and type specifications where @spec doesn't match actual implementation.

#### Categories
1. **Invalid Contracts** (14 errors)
   - Update @spec to match actual return types
   - Ensure success typing matches documentation

2. **Pattern Match Errors** (186 errors)
   - Fix patterns that can never match
   - Update case/with statements to handle all possible types
   - Remove impossible pattern matches

#### Priority Files
```
contexts/battle_analysis/core/battle_analyzer.ex
contexts/battle_analysis/domain/battle_metrics_calculator.ex
contexts/battle_analysis/domain/combat_log_helper.ex
contexts/battle_analysis/domain/participant_role_analyzer.ex
```

### Workstream Charlie: Control Flow Fixes (280 errors)
**Owner**: Team 3
**Priority**: High  
**Timeline**: 4-5 days

#### Scope
Fix functions with no_return errors and guard failures.

#### Categories
1. **No Return Errors** (178 errors)
   - Add proper return statements
   - Fix infinite loops/recursion
   - Ensure all code paths return values

2. **Guard Failures** (33 errors)
   - Fix guard clauses that always fail
   - Update function heads with correct guards
   - Remove impossible guard conditions

3. **Call Errors** (102 errors)
   - Fix function calls with wrong arity/types
   - Update Range.new calls to use proper syntax
   - Fix calls to non-existent functions

#### Priority Modules
```
contexts/combat_intelligence/domain/
contexts/threat_surveillance/domain/
platform/database/
```

### Workstream Delta: Business Logic Fixes (174 errors)
**Owner**: Team 4
**Priority**: Medium
**Timeline**: 3-4 days

#### Scope
Fix business logic errors including exact equality tests and extra range issues.

#### Categories
1. **Exact Equality Errors** (32 errors)
   - Fix comparisons that can never be true
   - Update ship type classifications
   - Fix role/type mismatches

2. **Extra Range Errors** (76 errors)
   - Fix case statements missing clauses
   - Add catch-all clauses where appropriate
   - Update enum mappings

3. **Pattern Match Coverage** (28 errors)
   - Ensure all patterns are covered
   - Add missing match clauses
   - Fix overlapping patterns

#### Focus Areas
```
contexts/battle_analysis/domain/strategic/patterns/resource_pattern.ex
contexts/battle_analysis/domain/strategic/patterns/tactical_patterns.ex
contexts/wormhole_operations/domain/analyzers/
```

## Implementation Strategy

### Phase 1: Preparation (Day 1)
1. Set up CI to track dialyzer error count
2. Create automated scripts for common fixes
3. Establish team communication channels
4. Create feature branches for each workstream

### Phase 2: Parallel Execution (Days 2-5)
- Each workstream works independently
- Daily sync meetings to avoid conflicts
- Continuous integration of fixes
- Regular dialyzer runs to track progress

### Phase 3: Integration & Validation (Days 6-7)
1. Merge all workstream branches
2. Full test suite execution
3. Final dialyzer validation
4. Performance testing
5. Documentation updates

## Success Metrics
- Zero dialyzer errors (excluding intentional ignores)
- All tests passing
- No performance regressions
- Code coverage maintained or improved

## Risk Mitigation
1. **Merge Conflicts**: Use atomic commits, frequent rebases
2. **Breaking Changes**: Comprehensive test coverage before changes
3. **Hidden Dependencies**: Careful analysis of function usage
4. **Performance Impact**: Benchmark critical paths

## Tooling & Scripts

### Unused Function Removal Script
```bash
#!/bin/bash
# Extract unused functions and generate removal commands
grep "unused_fun" dialyzer.txt | \
  sed 's/:unused_fun$//' | \
  awk -F: '{print "sed -i \"/"$NF"/,/^  end$/d\" "$1}' > remove_unused.sh
```

### Type Fix Helper
```elixir
# Script to update @spec based on success typing
defmodule DialyzerSpecFixer do
  def fix_spec(file, line, new_spec) do
    # Implementation to update @spec at specific line
  end
end
```

### Progress Tracking
```bash
# Monitor error reduction
watch -n 60 'mix dialyzer 2>&1 | grep "Total errors:" | tee dialyzer_progress.log'
```

## Communication Plan
- Slack channel: #dialyzer-cleanup
- Daily standups: 10 AM
- Shared tracking spreadsheet
- PR naming convention: `dialyzer/[workstream]-[module]-fixes`

## Post-Implementation
1. Add dialyzer to CI pipeline
2. Document common patterns/fixes
3. Team knowledge sharing session
4. Update coding standards

## Appendix: Error Distribution by Module

| Module | Unused | Pattern | No Return | Other | Total |
|--------|--------|---------|-----------|-------|-------|
| intelligence/core | 245 | 42 | 35 | 9 | 331 |
| combat_intelligence | 45 | 18 | 15 | 5 | 83 |
| threat_surveillance | 50 | 20 | 8 | 3 | 81 |
| corporation/core | 60 | 12 | 6 | 2 | 80 |
| wormhole_operations | 55 | 15 | 5 | 2 | 77 |
| Others | 385 | 79 | 109 | 121 | 694 |

This plan enables maximum parallelization while minimizing conflicts and ensuring systematic resolution of all dialyzer errors.