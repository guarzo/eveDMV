# Complex Architectural Issues - Final ~75 Errors

## High Complexity Issues (Require Refactoring)

### 1. Function Complexity Issues (8 errors)

#### Deep Nesting (4 errors)
**Pattern:** "Function body is nested too deep (max depth is 3, was X)"

- `lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex:125:26` - Depth 4
- `lib/eve_dmv/database/archive_manager/archive_operations.ex:126:19` - Depth 5  
- `lib/eve_dmv/database/archive_manager/restore_operations.ex:63:15` - Depth 4
- `lib/eve_dmv/intelligence/analyzers/member_activity_pattern_analyzer/timezone_analyzer.ex:34:8` - Combined with negated condition

**Solutions:**
1. Extract nested logic into private helper functions
2. Use early returns to reduce nesting
3. Replace nested if/else with case statements where appropriate

#### Too Many Parameters (2 errors)
**Pattern:** "Function takes too many parameters (arity is X, max is 6)"

- `lib/eve_dmv/workers/analysis_worker_pool.ex:326:8` - Arity 7
- `lib/eve_dmv/workers/analysis_worker_pool.ex:334:8` - Arity 8

**Solutions:**
1. Group related parameters into structs or maps
2. Use options parameter pattern: `func(required_params, opts \\ [])`
3. Extract parameter validation into helper functions

### 2. Module Dependencies (1 error)
**Pattern:** "Module has too many dependencies: X (max is 15)"

- `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex:1:11` - 22 dependencies

**Solutions:**
1. Split module into smaller, focused modules
2. Create shared service modules for common functionality
3. Use dependency injection patterns
4. Consider facade pattern for complex interactions

## Medium Complexity Issues (15+ errors)

### 1. Nested Module Aliasing (15+ errors)
**Pattern:** "Nested modules could be aliased at the top of the invoking module"

#### Files to fix:
- `lib/eve_dmv/intelligence_engine/plugins/character/combat_stats.ex:31:10`
- `lib/eve_dmv/telemetry/performance_monitor/health_monitor.ex` - Lines 48:10, 83:10, 126:10, 214:10, 255:10, 290:10
- `lib/eve_dmv_web/components/intelligence_components.ex:660:9`
- `lib/eve_dmv_web/live/battle_analysis_live.ex:842:9`
- `lib/eve_dmv_web/live/chain_intelligence_live.ex:316:34`
- `test/eve_dmv/killmails/killmail_raw_test.exs:249:7`
- `test/manual/manual_testing_data_generator.exs:210:13`
- `test/performance/performance_test_suite.exs` - Lines 245:13, 332:13, 339:11

**Fix Pattern:**
```elixir
# BEFORE:
def some_function do
  SomeModule.NestedModule.deeply_nested_function()
end

# AFTER:
alias SomeModule.NestedModule, as: NestedMod

def some_function do
  NestedMod.deeply_nested_function()
end
```

## Recommended Fix Order

### Phase 1: Simple Nested Module Aliases (30 minutes)
Start with the test files and simpler modules:
1. Test files (5 fixes) - 10 minutes
2. Component files (5 fixes) - 10 minutes  
3. Single-instance files (5 fixes) - 10 minutes

### Phase 2: Function Parameter Reduction (45 minutes)
1. **analysis_worker_pool.ex functions** - 45 minutes
   - Create parameter structs
   - Refactor function signatures
   - Update all call sites
   - Test compilation

### Phase 3: Function Complexity Reduction (60 minutes)
1. **archive_operations.ex:126** (depth 5) - 20 minutes
   - Extract nested logic into private functions
   - Use early returns

2. **restore_operations.ex:63** (depth 4) - 15 minutes
   - Similar extraction approach

3. **threat_analyzer.ex:125** (depth 4) - 15 minutes
   - Simplify conditional logic

4. **timezone_analyzer.ex:34** (negated + depth) - 10 minutes
   - Flip condition and reduce nesting

### Phase 4: Module Dependency Reduction (90-120 minutes)
1. **chain_intelligence_service.ex** (22 → 15 dependencies)
   - Analyze current dependencies
   - Group related functionality
   - Extract shared services
   - Create focused sub-modules
   - Update import statements

## Specific Refactoring Strategies

### For Deep Nesting:
```elixir
# BEFORE (depth 4):
def complex_function(data) do
  if condition1 do
    if condition2 do
      if condition3 do
        # deeply nested logic
      else
        # alternative path
      end
    end
  end
end

# AFTER (depth 2):
def complex_function(data) do
  with true <- condition1,
       true <- condition2,
       true <- condition3 do
    handle_success_case(data)
  else
    _ -> handle_alternative_case(data)
  end
end

defp handle_success_case(data), do: # extracted logic
defp handle_alternative_case(data), do: # extracted logic
```

### For Parameter Count:
```elixir
# BEFORE (8 parameters):
def process_analysis(worker_id, task_type, priority, timeout, metadata, options, callback, context)

# AFTER (3 parameters):
defstruct [:worker_id, :task_type, :priority, :timeout, :metadata, :options, :callback, :context]

def process_analysis(%AnalysisParams{} = params, opts \\ [], callback)
```

### For Module Dependencies:
```elixir
# Split large module into focused sub-modules:
# - ChainIntelligenceService.Core (5-6 dependencies)
# - ChainIntelligenceService.Analytics (4-5 dependencies)  
# - ChainIntelligenceService.Cache (3-4 dependencies)
# - ChainIntelligenceService.Events (3-4 dependencies)
```

## Expected Results

**Errors eliminated:** ~75 errors (remaining complex issues)
**Time invested:** 3-4 hours (requires careful refactoring)
**Before:** 76 errors
**After:** <10 errors (architectural excellence)

## Success Criteria

### Function Complexity:
- [ ] All functions have nesting depth ≤ 3
- [ ] All functions have parameter count ≤ 6
- [ ] Complex logic extracted into focused helper functions

### Module Dependencies:
- [ ] chain_intelligence_service.ex has ≤ 15 dependencies
- [ ] Related functionality grouped into coherent sub-modules
- [ ] Clear separation of concerns

### Code Organization:
- [ ] All nested modules properly aliased
- [ ] Consistent alias patterns across codebase
- [ ] Clean module structure throughout

## Notes

This phase requires the most careful consideration as it involves:
1. **Breaking changes** to function signatures
2. **Module restructuring** that affects multiple files
3. **Logic refactoring** that could introduce bugs

Ensure comprehensive testing after each major refactoring step.

The goal is to achieve a production-ready codebase with <10 remaining credo errors, representing architectural excellence and maintainability.