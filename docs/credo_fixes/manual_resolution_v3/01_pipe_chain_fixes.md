# Manual Resolution: Pipe Chain Fixes (136 errors)

## Error Pattern: "Pipe chain should start with a raw value"

This error occurs when a pipe chain starts with a function call instead of a raw value.

## How to Fix Each Instance

### WRONG Pattern:
```elixir
SomeModule.function(data) |> transform() |> process()
```

### CORRECT Pattern:
```elixir
data
|> SomeModule.function()
|> transform()
|> process()
```

## Files to Fix (in order of impact):

### 1. lib/eve_dmv/analytics/player_stats_engine.ex
**Line 85:11** - Fix pipe chain starting point

### 2. lib/eve_dmv/analytics/ship_stats_engine.ex
**Line 82:9** and **Line 181:7** - Fix pipe chain starting points

### 3. lib/eve_dmv/contexts/corporation_analysis/analyzers/member_activity_analyzer.ex
**Line 414:5** - Fix pipe chain starting point

### 4. lib/eve_dmv/contexts/corporation_analysis/analyzers/participation_analyzer.ex
**Line 500:5** and **Line 866:5** - Fix pipe chain starting points

### 5. lib/eve_dmv/contexts/fleet_operations/analyzers/composition_analyzer.ex
**Line 113:7** - Fix pipe chain starting point

### 6. lib/eve_dmv/contexts/fleet_operations/analyzers/pilot_analyzer.ex
**Lines to fix**: 95:11, 320:13, 476:5, 603:5, 619:9, 644:7

### 7. lib/eve_dmv/contexts/fleet_operations/domain/effectiveness_calculator.ex
**Line 731:7** - Fix pipe chain starting point

### 8. lib/eve_dmv/contexts/market_intelligence/domain/price_service.ex
**Line 180:11** - Fix pipe chain starting point

## Step-by-Step Instructions:

1. **Open the file** in your editor
2. **Go to the specific line number** (use Ctrl+G or Cmd+L)
3. **Find the pipe chain** that starts with a function call
4. **Identify the first argument** to that function call
5. **Restructure** to start with the raw value:

### Example Fix:
```elixir
# BEFORE (Line causing error):
Map.get(data, :key) |> transform() |> process()

# AFTER (Fixed):
data
|> Map.get(:key)
|> transform()
|> process()
```

### Another Example:
```elixir
# BEFORE:
Enum.filter(items, &valid?/1) |> Enum.map(&transform/1) |> Enum.take(5)

# AFTER:
items
|> Enum.filter(&valid?/1)
|> Enum.map(&transform/1)
|> Enum.take(5)
```

## Verification:
After fixing each file:
1. Save the file
2. Run `mix compile` to ensure no syntax errors
3. The pipe chain should now start with a variable or literal value
4. Continue to next file

## Progress Tracking:
- [ ] analytics/player_stats_engine.ex (1 fix)
- [ ] analytics/ship_stats_engine.ex (2 fixes)
- [ ] contexts/corporation_analysis/analyzers/member_activity_analyzer.ex (1 fix)
- [ ] contexts/corporation_analysis/analyzers/participation_analyzer.ex (2 fixes)
- [ ] contexts/fleet_operations/analyzers/composition_analyzer.ex (1 fix)
- [ ] contexts/fleet_operations/analyzers/pilot_analyzer.ex (6 fixes)
- [ ] contexts/fleet_operations/domain/effectiveness_calculator.ex (1 fix)
- [ ] contexts/market_intelligence/domain/price_service.ex (1 fix)

Continue with remaining files in credo.txt following the same pattern.