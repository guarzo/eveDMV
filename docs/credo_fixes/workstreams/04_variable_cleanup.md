# Workstream 4: Variable Cleanup

## Overview
- **Total Errors**: 70+ errors (7.5% of all errors)
- **Complexity**: MEDIUM - Requires understanding function logic
- **Impact**: Cleaner code, fewer bugs, 7.5% error reduction
- **Time Estimate**: 3-4 hours

## Error Type to Fix

### Variable Redeclaration (~70 errors)
```elixir
# INCORRECT - Same variable name reused
def analyze_data(input) do
  result = initial_analysis(input)
  # ... some code ...
  result = deep_analysis(input)  # Redeclaring 'result'
  # ... some code ...
  result = final_analysis(result) # Redeclaring again
  result
end

# CORRECT - Descriptive variable names
def analyze_data(input) do
  initial_result = initial_analysis(input)
  # ... some code ...
  deep_result = deep_analysis(input)
  # ... some code ...
  final_result = final_analysis(deep_result)
  final_result
end
```

## Common Variable Names Being Redeclared

Based on the codebase analysis, these variables are most commonly redeclared:

1. **`errors`** (15+ instances) - Error accumulation patterns
2. **`results`** (12+ instances) - Multi-step calculations
3. **`params`** (10+ instances) - Parameter transformation
4. **`data`** (8+ instances) - Data pipeline processing
5. **`state`** (6+ instances) - State updates in GenServers
6. **`query`** (5+ instances) - Query building
7. **`opts`** (4+ instances) - Option processing

## Implementation Strategy

### Pattern 1: Accumulator Pattern (Most Common)
```elixir
# INCORRECT - Found in many analyzer modules
def calculate_metrics(data) do
  metrics = basic_metrics(data)
  metrics = add_performance_metrics(metrics, data)  # Redeclaration
  metrics = add_timing_metrics(metrics, data)       # Redeclaration
  metrics
end

# CORRECT - Option 1: Pipeline
def calculate_metrics(data) do
  data
  |> basic_metrics()
  |> add_performance_metrics(data)
  |> add_timing_metrics(data)
end

# CORRECT - Option 2: Descriptive names
def calculate_metrics(data) do
  basic = basic_metrics(data)
  with_performance = add_performance_metrics(basic, data)
  with_timing = add_timing_metrics(with_performance, data)
  with_timing
end
```

### Pattern 2: Conditional Building
```elixir
# INCORRECT - Common in query builders
def build_query(params) do
  query = from(k in Killmail)
  
  query = if params.start_date do
    where(query, [k], k.timestamp >= ^params.start_date)
  else
    query  # Same variable
  end
  
  query = if params.end_date do
    where(query, [k], k.timestamp <= ^params.end_date)
  else
    query  # Same variable
  end
  
  query
end

# CORRECT - Use pipeline with conditional function
def build_query(params) do
  from(k in Killmail)
  |> maybe_add_start_date(params.start_date)
  |> maybe_add_end_date(params.end_date)
end

defp maybe_add_start_date(query, nil), do: query
defp maybe_add_start_date(query, date) do
  where(query, [k], k.timestamp >= ^date)
end
```

### Pattern 3: Error Collection
```elixir
# INCORRECT - Common in validation functions
def validate_all(data) do
  errors = validate_required(data)
  errors = errors ++ validate_format(data)    # Redeclaration
  errors = errors ++ validate_business_rules(data)  # Redeclaration
  errors
end

# CORRECT - Use Enum.reduce or parallel validation
def validate_all(data) do
  [
    validate_required(data),
    validate_format(data),
    validate_business_rules(data)
  ]
  |> List.flatten()
  |> Enum.uniq()
end
```

## Files with Most Variable Redeclarations

### Critical Files (5+ redeclarations each)
1. `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer.ex` - 7 redeclarations
   - Mostly `results` and `errors`
   - Complex analysis functions

2. `lib/eve_dmv/database/query_plan_analyzer/plan_analyzer.ex` - 6 redeclarations
   - Query building patterns
   - Accumulator patterns

3. `lib/eve_dmv/contexts/player_profile/analyzers/combat_stats_analyzer.ex` - 5 redeclarations
   - Metrics calculation
   - State accumulation

### By Module Type
- **Analyzers** (25+ total): `results`, `metrics`, `analysis`
- **Query Builders** (15+ total): `query`, `filters`, `conditions`  
- **Validators** (10+ total): `errors`, `warnings`
- **GenServers** (10+ total): `state`, `new_state`
- **LiveViews** (10+ total): `socket`, `assigns`

## Refactoring Guidelines

### 1. Use Pipelines Where Appropriate
```elixir
# When each step transforms the previous result
data
|> step_one()
|> step_two()
|> step_three()
```

### 2. Use Descriptive Names for Intermediate Results
```elixir
# When you need to reference intermediate values
raw_data = fetch_data()
validated_data = validate(raw_data)
enriched_data = enrich(validated_data)
final_result = transform(enriched_data)
```

### 3. Extract Helper Functions
```elixir
# For conditional accumulation
defp maybe_add_filter(query, nil, _field), do: query
defp maybe_add_filter(query, value, field) do
  where(query, ^dynamic([t], field(t, ^field) == ^value))
end
```

### 4. Use Enum.reduce for Accumulation
```elixir
# For collecting results
def collect_all_errors(validations) do
  Enum.reduce(validations, [], fn validation, acc ->
    case validation do
      {:error, errors} -> acc ++ errors
      _ -> acc
    end
  end)
end
```

## Common Anti-Patterns to Fix

### Anti-Pattern 1: Shadowing in Case Statements
```elixir
# INCORRECT
def process(data) do
  result = initial_check(data)
  
  case result do
    {:ok, data} ->  # 'data' shadows parameter
      final_process(data)
    {:error, _} ->
      result
  end
end

# CORRECT  
def process(data) do
  case initial_check(data) do
    {:ok, checked_data} ->
      final_process(checked_data)
    {:error, _} = error ->
      error
  end
end
```

### Anti-Pattern 2: Accumulating in Comprehensions
```elixir
# INCORRECT
def calculate_all(items) do
  results = []
  for item <- items do
    results = results ++ [calculate(item)]  # Can't do this
  end
  results
end

# CORRECT
def calculate_all(items) do
  for item <- items do
    calculate(item)
  end
end
```

## Testing Strategy

When fixing variable redeclarations:

1. **Ensure Semantic Equivalence**
   - The refactored code must produce identical results
   - Test with edge cases

2. **Check Variable Scope**
   - Ensure variables are available where needed
   - Watch for accidental shadowing

3. **Verify Performance**
   - Some redeclarations might be performance optimizations
   - Benchmark if concerned

## Expected Results

### Before
```
┃ [F] ↑ Variable "results" was declared more than once.
┃       lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer.ex:234
Total: 70+ variable redeclaration warnings
```

### After
```
Variable warnings: 0
Remaining total errors: ~860 (from 930)
Code is more readable and less error-prone
```

## Success Criteria
1. Zero variable redeclaration warnings
2. All tests pass
3. No performance regressions
4. Improved code readability
5. Clearer variable naming throughout

## Quick Fix Script

```bash
# Find all variable redeclarations
mix credo --strict | grep "Variable.*was declared" | cut -d'"' -f2 | sort | uniq -c | sort -nr

# This will show which variable names are most problematic
```

This workstream eliminates confusing variable reuse and makes code flow clearer.