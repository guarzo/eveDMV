# Complex Refactoring Issues (Final 20+ errors)

## Overview
These are the most complex issues requiring careful refactoring and architectural consideration.

## High Priority Complex Issues

### 1. Module Dependencies (1 error - HIGH IMPACT)
**File**: `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex:1:11`
**Issue**: Module has 24 dependencies (max is 15)

**Solution Strategy**:
1. **Analyze dependencies** to identify groupings
2. **Extract service modules** for related functionality  
3. **Use dependency injection** patterns
4. **Create facade interfaces** for complex interactions

### 2. Function Complexity (1 error - MEDIUM IMPACT)
**File**: `lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex:125:26`
**Issue**: Function body is nested too deep (max depth is 3, was 4)

**Solution Strategy**:
1. **Extract nested logic** into private helper functions
2. **Use early returns** to reduce nesting
3. **Replace nested if/else** with case statements
4. **Apply guard clauses** where appropriate

### 3. Variable Redeclaration (2 errors - LOW IMPACT)
**Files**:
- `lib/eve_dmv/intelligence/core/correlation_engine.ex:340:5` - "summary_points"
- `lib/eve_dmv/contexts/surveillance/domain/chain_threat_analyzer.ex:92:5` - "threats"

**Solution Strategy**: Use descriptive variable names to show progression

## Styling & Format Issues

### 4. Long Quote Blocks (10 errors)
**Pattern**: "Avoid long quote blocks"

**Files**:
- `test/support/ui_case.ex:26:5`
- `test/support/intelligence_case.ex:11:5` 
- `lib/eve_dmv_web.ex:85:5`
- `lib/eve_dmv_web.ex:41:5`
- `test/support/conn_case.ex:21:5`
- `lib/eve_dmv_web/components/reusable_components.ex:25:5`
- `lib/eve_dmv/error_handler.ex:68:5`
- `lib/eve_dmv/database/repository.ex:34:5`
- `lib/eve_dmv/contexts/bounded_context.ex:40:5`
- `lib/eve_dmv/intelligence/analyzer.ex:48:5`

### 5. Logic Pattern Issues (5 errors)

#### with/case Conversions (4 errors):
- `lib/eve_dmv/workers/realtime_task_supervisor.ex:60:5`
- `lib/eve_dmv/workers/background_task_supervisor.ex:60:5`
- `lib/eve_dmv/intelligence/intelligence_scoring/recruitment_scoring.ex:24:5`
- `lib/eve_dmv/database/materialized_view_manager/view_metrics.ex:195:7`

#### Nested Function Calls (2 errors):
- `test/eve_dmv/killmails/killmail_raw_test.exs:36:16`
- `lib/eve_dmv/intelligence/intelligence_scoring/fleet_scoring.ex:275:7`

#### Unless Condition (1 error):
- `lib/eve_dmv/intelligence/analyzers/member_activity_pattern_analyzer/timezone_analyzer.ex:34:5`

### 6. Minor Issues (4 errors)

#### Predicate Function Naming (1 error):
- `lib/eve_dmv/contexts/surveillance/domain/chain_activity_tracker.ex:142:8`

#### Unused Return Values (2 errors):
- `lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/acquisition_planner.ex:47:5`
- `lib/eve_dmv/intelligence/advanced_analytics.ex:265:9`

#### Logger Metadata (2 errors):
- `lib/eve_dmv/contexts/combat_intelligence/infrastructure/killmail_event_processor.ex:33:65`
- `lib/eve_dmv/contexts/fleet_operations/infrastructure/killmail_fleet_processor.ex:17:60`

#### IO.puts in Tests (2 errors):
- `test/test_helper.exs:18:3`
- `test/test_helper.exs:13:3`

#### Trailing Whitespace (1 error):
- `lib/eve_dmv/intelligence/core/correlation_engine.ex:294:25`

## Detailed Fix Instructions

### 1. Module Dependencies Reduction (60-90 minutes)

**chain_intelligence_service.ex** needs architectural refactoring:

```elixir
# Current structure (24 dependencies):
defmodule ChainIntelligenceService do
  alias Module1
  alias Module2
  # ... 22 more aliases
end

# Proposed structure (3 sub-modules, each <15 dependencies):
defmodule ChainIntelligenceService do
  alias ChainIntelligenceService.{Analytics, Cache, Events}
  
  def some_function(args) do
    Analytics.analyze(args)
  end
end

defmodule ChainIntelligenceService.Analytics do
  # 5-6 analytics-related dependencies
end

defmodule ChainIntelligenceService.Cache do  
  # 4-5 cache-related dependencies
end

defmodule ChainIntelligenceService.Events do
  # 3-4 event-related dependencies  
end
```

### 2. Function Complexity Reduction (30 minutes)

**threat_analyzer.ex:125** - Extract nested logic:

```elixir
# BEFORE (nested depth 4):
def analyze_pilots(pilots) do
  if condition1 do
    if condition2 do
      if condition3 do
        # deeply nested logic
      else
        # alternative
      end
    end
  end
end

# AFTER (depth 2):
def analyze_pilots(pilots) do
  with true <- condition1,
       true <- condition2,
       true <- condition3 do
    handle_analysis_success(pilots)
  else
    _ -> handle_analysis_failure(pilots)
  end
end

defp handle_analysis_success(pilots), do: # extracted logic
defp handle_analysis_failure(pilots), do: # extracted logic
```

### 3. Variable Redeclaration (10 minutes)

**correlation_engine.ex:340** - "summary_points":
```elixir
# BEFORE:
summary_points = initial_points()
summary_points = add_correlation_points(summary_points)
summary_points = finalize_points(summary_points)

# AFTER:
initial_points = initial_points()
correlation_points = add_correlation_points(initial_points)
final_summary_points = finalize_points(correlation_points)
```

**chain_threat_analyzer.ex:92** - "threats":
```elixir
# BEFORE:
threats = detect_basic_threats()
threats = analyze_threat_patterns(threats)
threats = prioritize_threats(threats)

# AFTER:
basic_threats = detect_basic_threats()
analyzed_threats = analyze_threat_patterns(basic_threats)
prioritized_threats = prioritize_threats(analyzed_threats)
```

## Quick Fixes (30 minutes total)

### Long Quote Blocks (15 minutes):
Shorten @moduledoc strings to be more concise.

### with/case Conversions (10 minutes):
```elixir
# BEFORE:
with {:ok, data} <- fetch_data() do
  process(data)
else
  error -> handle_error(error)
end

# AFTER:
case fetch_data() do
  {:ok, data} -> process(data)
  error -> handle_error(error)
end
```

### Predicate Function (1 minute):
```elixir
# BEFORE:
defp is_hostile_activity?(activity)

# AFTER:
defp hostile_activity?(activity)
```

### Misc Issues (4 minutes):
- Remove IO.puts from test files
- Fix trailing whitespace
- Add `_ = ` to unused Enum return values

## Execution Timeline

### Phase 1: Quick Wins (45 minutes)
1. **Long quote blocks** (15 min)
2. **with/case conversions** (10 min)  
3. **Variable redeclaration** (10 min)
4. **Misc fixes** (10 min)

### Phase 2: Medium Complexity (30 minutes)
5. **Function complexity** (30 min)

### Phase 3: Architectural (90 minutes)
6. **Module dependencies** (90 min)

## Expected Results

### After Phase 1:
- **Quick wins completed**: ~15 errors eliminated
- **Remaining**: ~5-10 errors

### After Phase 2:  
- **Function complexity resolved**
- **Remaining**: ~4-9 errors

### After Phase 3:
- **Module architecture improved**
- **Final**: <5 errors total

## Final Target
- **Total time**: 2.5-3 hours for complex issues
- **Final error count**: <10 total issues  
- **Quality achievement**: Production-ready codebase
- **Overall reduction**: 95%+ from original baseline

This represents the final push to achieve architectural excellence in the codebase.