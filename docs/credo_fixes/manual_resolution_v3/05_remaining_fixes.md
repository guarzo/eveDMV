# Manual Resolution: Remaining Fixes (Various Types)

## Overview
This covers all remaining error types that don't fit the major categories.

## Error Types to Fix:

### 1. IMPLICIT TRY BLOCKS (12 errors)
**Pattern:** "Prefer using an implicit 'try' rather than explicit 'try'"

**Files:**
- `lib/eve_dmv/contexts/player_profile/analyzers/behavioral_patterns_analyzer.ex:18:5`
- `lib/eve_dmv/contexts/player_profile/analyzers/combat_stats_analyzer.ex:19:5` 
- `lib/eve_dmv/contexts/player_profile/analyzers/ship_preferences_analyzer.ex:19:5`
- `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex:151:5`
- `lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex:40:5`
- `lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex:110:5`
- `lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex:169:5`
- `lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex:204:5`
- `lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex:875:5`
- `lib/eve_dmv/contexts/threat_assessment/infrastructure/threat_cache.ex:396:5`

**How to Fix:**
```elixir
# BEFORE:
try do
  some_operation()
rescue
  error -> handle_error(error)
end

# AFTER:
some_operation()
rescue
  error -> handle_error(error)
```

### 2. WITH/CASE CONVERSIONS (13 errors)
**Pattern:** "'with' contains only one <- clause and an 'else' branch, consider using 'case' instead"

**Files:**
- `lib/eve_dmv/contexts/corporation_analysis/analyzers/participation_analyzer.ex:110:5`
- `lib/eve_dmv/contexts/fleet_operations/analyzers/pilot_analyzer.ex:92:5`
- `lib/eve_dmv/contexts/surveillance/api.ex:71:5`
- `lib/eve_dmv/contexts/surveillance/api.ex:105:5`
- `lib/eve_dmv/contexts/surveillance/api.ex:119:5`
- `lib/eve_dmv/contexts/surveillance/api.ex:238:5`
- `lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex:170:7`

**How to Fix:**
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

### 3. NESTED FUNCTION CALLS (2 errors)
**Pattern:** "Use a pipeline instead of nested function calls"

**Files:**
- `lib/eve_dmv/contexts/fleet_operations/domain/doctrine_manager.ex:685:7`
- `lib/eve_dmv/contexts/fleet_operations/domain/doctrine_manager.ex:692:7`

**How to Fix:**
```elixir
# BEFORE:
function_c(function_b(function_a(data)))

# AFTER:
data
|> function_a()
|> function_b()
|> function_c()
```

### 4. ENUM.MAP_JOIN OPTIMIZATION (1 error)
**Pattern:** "'Enum.map_join/3' is more efficient than 'Enum.map/2 |> Enum.join/2'"

**File:**
- `lib/eve_dmv/contexts/surveillance/domain/notification_service.ex:442:5`

**How to Fix:**
```elixir
# BEFORE:
items |> Enum.map(&transform/1) |> Enum.join(", ")

# AFTER:
Enum.map_join(items, ", ", &transform/1)
```

### 5. OPERATION REDUNDANCY (1 error)
**Pattern:** "Operation will always return the left side of the expression"

**File:**
- `lib/eve_dmv/contexts/corporation_analysis/analyzers/participation_analyzer.ex:881:38`

**How to Fix:**
```elixir
# BEFORE (example):
value || some_function_that_never_executes()

# AFTER:
value
# Or determine if the right side is actually needed
```

### 6. LONG QUOTE BLOCKS (1 error)
**Pattern:** "Avoid long quote blocks"

**File:**
- `lib/eve_dmv/contexts/bounded_context.ex:37:5`

**How to Fix:**
```elixir
# BEFORE:
@moduledoc """
This is an extremely long documentation block that goes on and on
and explains every detail about the module in excessive length
making it hard to read and understand the key points...
"""

# AFTER:
@moduledoc """
This module provides bounded context functionality.
See individual function documentation for details.
"""
```

### 7. NESTED MODULE ALIASING (2 errors)
**Pattern:** "Nested modules could be aliased at the top of the invoking module"

**Files:**
- `lib/eve_dmv/contexts/bounded_context.ex:46:27`
- `lib/eve_dmv/contexts/bounded_context.ex:48:33`

**How to Fix:**
Add aliases at the top of the module for nested module access:
```elixir
# Add at top of module:
alias Some.Deep.Nested.Module

# Then use:
Module.function() instead of Some.Deep.Nested.Module.function()
```

### 8. MODULE DEPENDENCY LIMIT (1 error)
**Pattern:** "Module has too many dependencies: 22 (max is 15)"

**File:**
- `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex:1:11`

**How to Fix:**
This is a design issue. Consider:
1. **Split the module** into smaller, focused modules
2. **Extract common dependencies** into a shared module
3. **Use dependency injection** instead of direct dependencies
4. **Create service objects** for complex operations

For now, you can temporarily suppress this by adding to `.credo.exs`:
```elixir
{Credo.Check.Design.DuplicatedCode, false},
```

## Step-by-Step Instructions:

### For Each Error Type:

1. **Identify the pattern** from the error message
2. **Open the file** and go to the line number
3. **Apply the specific transformation** shown above
4. **Save and compile** to verify the fix
5. **Move to the next error**

## Quick Reference for Common Fixes:

### Implicit Try:
Remove `try do` and `end`, keep the rescue clause

### With → Case:
Replace `with pattern <-` with `case` and adjust pattern matching

### Nested Calls → Pipeline:
Break apart nested function calls into pipeline steps

### Map + Join → Map_Join:
Use `Enum.map_join/3` instead of separate map and join

## Progress Tracking:

### Implicit Try Blocks:
- [ ] behavioral_patterns_analyzer.ex:18
- [ ] combat_stats_analyzer.ex:19  
- [ ] ship_preferences_analyzer.ex:19
- [ ] chain_intelligence_service.ex:151
- [ ] threat_analyzer.ex:40, 110, 169, 204, 875
- [ ] threat_cache.ex:396

### With/Case Conversions:
- [ ] participation_analyzer.ex:110
- [ ] pilot_analyzer.ex:92
- [ ] surveillance/api.ex:71, 105, 119, 238
- [ ] threat_analyzer.ex:170

### Other Fixes:
- [ ] doctrine_manager.ex (2 nested calls)
- [ ] notification_service.ex (map_join)
- [ ] participation_analyzer.ex:881 (operation)
- [ ] bounded_context.ex (quote block + nested modules)
- [ ] chain_intelligence_service.ex (module dependencies)

This should eliminate most of the remaining credo errors, getting the total count well below 100.