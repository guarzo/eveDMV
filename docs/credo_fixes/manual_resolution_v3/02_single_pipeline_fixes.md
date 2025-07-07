# Manual Resolution: Single Pipeline Fixes (62 errors)

## Error Pattern: "Use a function call when a pipeline is only one function long"

This error occurs when you use a pipe operator for a single function call.

## How to Fix Each Instance

### WRONG Pattern:
```elixir
data |> SomeModule.function()
value |> transform()
```

### CORRECT Pattern:
```elixir
SomeModule.function(data)
transform(value)
```

## Files to Fix (with exact line numbers):

### 1. lib/eve_dmv/contexts/corporation_analysis/infrastructure/analysis_cache.ex
**Line 173:7**
```elixir
# Find the line with single pipeline
# Change: something |> function() 
# To: function(something)
```

### 2. lib/eve_dmv/contexts/corporation_analysis/infrastructure/corporation_repository.ex
**Line 41:7**
```elixir
# Find the line with single pipeline
# Change: data |> Repository.save()
# To: Repository.save(data)
```

### 3. lib/eve_dmv/contexts/fleet_operations/domain/effectiveness_calculator.ex
**Line 731:7**
```elixir
# Find the line with single pipeline
# Change: result |> calculate()
# To: calculate(result)
```

### 4. lib/eve_dmv/contexts/killmail_processing/domain/ingestion_service.ex
**Line 132:7**
```elixir
# Change single pipeline to direct function call
```

### 5. lib/eve_dmv/contexts/market_intelligence/domain/price_service.ex
**Line 94:7** and **Line 235:9**
```elixir
# Fix both single pipeline instances
```

### 6. lib/eve_dmv/contexts/player_profile/analyzers/combat_stats_analyzer.ex
**Line 338:5**
```elixir
# Change: stats |> analyze()
# To: analyze(stats)
```

### 7. lib/eve_dmv/contexts/player_profile/analyzers/ship_preferences_analyzer.ex
**Line 169:7**
```elixir
# Change single pipeline to direct call
```

### 8. lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex
**Line 575:11**
```elixir
# Change single pipeline to direct call
```

### 9. lib/eve_dmv/contexts/threat_assessment/domain/threat_analyzer.ex
**Line 634:63**
```elixir
# Change single pipeline to direct call
```

### 10. lib/eve_dmv/contexts/threat_assessment/infrastructure/threat_cache.ex
**Line 219:7** and **Line 366:7**
```elixir
# Fix both single pipeline instances
```

### 11. lib/eve_dmv/contexts/threat_assessment/infrastructure/threat_repository.ex
**Line 96:7** and **Line 246:5**
```elixir
# Fix both single pipeline instances
```

## Step-by-Step Instructions:

1. **Open the file** in your editor
2. **Go to the exact line number** using Ctrl+G or Cmd+L
3. **Find the pipeline** with only one function after |>
4. **Convert** to direct function call:

### Common Conversion Examples:

```elixir
# Pattern 1: Simple function call
data |> process() → process(data)

# Pattern 2: Module function call  
value |> Module.function() → Module.function(value)

# Pattern 3: Function with additional arguments
item |> transform(arg1, arg2) → transform(item, arg1, arg2)

# Pattern 4: Nested module access
data |> Some.Module.function() → Some.Module.function(data)
```

## Common Patterns You'll See:

### Enum Operations:
```elixir
# BEFORE:
items |> Enum.count() 
list |> Enum.empty?()
data |> Enum.reverse()

# AFTER:
Enum.count(items)
Enum.empty?(list)
Enum.reverse(data)
```

### Map Operations:
```elixir
# BEFORE:
map |> Map.get(:key)
data |> Map.put(:key, value)

# AFTER:
Map.get(map, :key)
Map.put(data, :key, value)
```

### Repository/Service Calls:
```elixir
# BEFORE:
entity |> Repository.save()
data |> Service.process()

# AFTER:
Repository.save(entity)
Service.process(data)
```

## Verification:
After each fix:
1. Ensure the function still receives its arguments in the correct order
2. Save the file
3. Run `mix compile` to check for syntax errors
4. The single |> should be eliminated

## Progress Tracking:
Check off each file as you complete it:
- [ ] contexts/corporation_analysis/infrastructure/analysis_cache.ex
- [ ] contexts/corporation_analysis/infrastructure/corporation_repository.ex  
- [ ] contexts/fleet_operations/domain/effectiveness_calculator.ex
- [ ] contexts/killmail_processing/domain/ingestion_service.ex
- [ ] contexts/market_intelligence/domain/price_service.ex (2 fixes)
- [ ] contexts/player_profile/analyzers/combat_stats_analyzer.ex
- [ ] contexts/player_profile/analyzers/ship_preferences_analyzer.ex
- [ ] contexts/surveillance/domain/chain_intelligence_service.ex
- [ ] contexts/threat_assessment/domain/threat_analyzer.ex
- [ ] contexts/threat_assessment/infrastructure/threat_cache.ex (2 fixes)
- [ ] contexts/threat_assessment/infrastructure/threat_repository.ex (2 fixes)

This should eliminate 62 single pipeline errors.